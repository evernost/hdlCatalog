-- ============================================================================
-- Project        : hdlCatalog/blinky
-- Module name    : blinky
-- File name      : blinky.vhd
-- File type      : VHDL 2008
-- Purpose        : simple blinker with soft on/off
-- Author         : QuBi (nitrogenium@outlook.fr)
-- Creation date  : July 16th, 2025
-- ----------------------------------------------------------------------------
-- Best viewed with space indentation (2 spaces)
-- ============================================================================

-- ============================================================================
-- LIBRARIES
-- ============================================================================
-- Standard libraries
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

-- Project libraries
library work; use work.blinky_pkg.all;



-- ============================================================================
-- I/O DESCRIPTION
-- ============================================================================
entity blinky is
generic
(
  RESET_SYNC      : BOOLEAN;
  RESET_POL       : STD_LOGIC;
  CLOCK_FREQ_MHZ  : REAL;
  BLINK_FREQ_HZ   : REAL := 1.00
);
port
( 
  clock     : in STD_LOGIC;
  reset     : in STD_LOGIC; 
  
  blink_out : out STD_LOGIC
);
end blinky;



-- ============================================================================
-- ARCHITECTURE
-- ============================================================================
architecture archDefault of blinky is

  type PWM_DUTY_DIRECTION_TYPE is (PWM_DUTY_UP, PWM_DUTY_DOWN);
  
  -- PWM signal frequency
  -- The exact value does not really matter (generally kHz-ish is enough)
  -- If too low, the LED will have a noticeable flicker
  -- If too high, the overall brightness might decrease (LED cutoff frequency)
  constant PWM_FREQ_KHZ : REAL := 1.00; 

  -- Number of PWM steps available
  constant PWM_STEPS : INTEGER := (2**PWM_RESOL_NBITS)-1;

  -- Prescaler threshold value for the PWM frequency generation
  -- Prescaler counts from 0...nMax hence nMax = (fclk/fpresc)-1
  constant PWM_PRESC_CNT_THRESH : UNSIGNED(31 downto 0) := to_unsigned(INTEGER(CLOCK_FREQ_MHZ*1000.0/(PWM_FREQ_KHZ*REAL(PWM_STEPS)))-1, 32);
  
  constant TIMER_INIT_VAL       : UNSIGNED(31 downto 0) := to_unsigned(INTEGER((CLOCK_FREQ_MHZ*1000000.0/(BLINK_FREQ_HZ*REAL((2*(BRIGHTNESS_STEPS-1))))))-1, 32);
  
  signal pwm_presc_cnt  : STD_LOGIC_VECTOR(31 downto 0);
  signal pwm_cnt        : STD_LOGIC_VECTOR((PWM_RESOL_NBITS-1) downto 0);
  signal pwm_cnt_en     : STD_LOGIC;
  signal pwm_duty       : STD_LOGIC_VECTOR((PWM_RESOL_NBITS-1) downto 0);
  signal pwm_duty_dir   : PWM_DUTY_DIRECTION_TYPE;
  signal pwm_out        : STD_LOGIC;

  signal timer          : STD_LOGIC_VECTOR(31 downto 0);
  signal timer_over     : STD_LOGIC;
  
  signal brightness     : INTEGER range 0 to (BRIGHTNESS_STEPS-1);

begin



  -- --------------------------------------------------------------------------
  -- PROCESS NAME: timer process
  -- DESCRIPTION: 
  -- Generate a 'tick' every time the PWM value has to change.
  -- --------------------------------------------------------------------------
  p_timer : process(clock, reset)
  procedure resetProcedure is 
  begin
    timer       <= STD_LOGIC_VECTOR(TIMER_INIT_VAL);
    timer_over  <= '0';
  end resetProcedure;
  begin
    if (not(RESET_SYNC) and (reset = RESET_POL)) then
      resetProcedure;
    elsif (clock'event and (clock = '1')) then
      if (RESET_SYNC and (reset = RESET_POL)) then
        resetProcedure;
      else
        if (timer = STD_LOGIC_VECTOR(to_unsigned(0, timer'length))) then
          timer       <= STD_LOGIC_VECTOR(TIMER_INIT_VAL);
          timer_over  <= '1';
        else
          timer       <= STD_LOGIC_VECTOR(UNSIGNED(timer) - 1);
          timer_over  <= '0';
        end if;
      end if;
    end if;
  end process p_timer;



  -- --------------------------------------------------------------------------
  -- PROCESS NAME: PWM modulation 
  -- DESCRIPTION: 
  -- Modulates the PWM duty cycle, calculates the new value on each Timer tick.
  -- --------------------------------------------------------------------------
  p_pwmMod : process(clock, reset)
  procedure resetProcedure is 
  begin
    brightness    <= 0;
    pwm_duty      <= (others => '0');
    pwm_duty_dir  <= PWM_DUTY_UP;
  end resetProcedure;
  begin
    if (not(RESET_SYNC) and (reset = RESET_POL)) then
      resetProcedure;
    elsif (clock'event and (clock = '1')) then
      if (RESET_SYNC and (reset = RESET_POL)) then
        resetProcedure;
      else
        if (timer_over = '1') then
          if (pwm_duty_dir = PWM_DUTY_UP) then
            if (brightness >= (BRIGHTNESS_STEPS-1)) then
              brightness    <= brightness - 1;
              pwm_duty_dir  <= PWM_DUTY_DOWN;
            else 
              brightness    <= brightness + 1;
            end if;
          else
            if (brightness = 0) then
              brightness    <= brightness + 1;
              pwm_duty_dir  <= PWM_DUTY_UP;
            else 
              brightness    <= brightness - 1;
            end if;
          end if;
        
          pwm_duty <= BRIGHTNESS_ROM(brightness);
        else
          -- Timer hasn't ticked: nothing to do.
        end if;
      end if;
    end if;
  end process p_pwmMod;



  -- --------------------------------------------------------------------------
  -- PROCESS NAME: PWM generation 
  -- DESCRIPTION: 
  -- Generates the PWM signal.
  -- --------------------------------------------------------------------------
  p_pwmGen : process(clock, reset)
  procedure resetProcedure is 
  begin
    pwm_cnt       <= (others => '0');
    pwm_presc_cnt <= (others => '0');
    pwm_cnt_en    <= '0';
    pwm_out       <= '0';
  end resetProcedure;
  begin
    if (not(RESET_SYNC) and (reset = RESET_POL)) then
      resetProcedure;
    elsif (clock'event and (clock = '1')) then
      if (RESET_SYNC and (reset = RESET_POL)) then
        resetProcedure;
      else
        
        -- PWM clock prescaler (derived from the main clock)
        if (UNSIGNED(pwm_presc_cnt) >= PWM_PRESC_CNT_THRESH) then
          pwm_cnt_en <= '1';
          pwm_presc_cnt <= (others => '0');
        else 
          pwm_cnt_en <= '0';
          pwm_presc_cnt <= STD_LOGIC_VECTOR(UNSIGNED(pwm_presc_cnt) + 1);
        end if;
        
        -- PWM main counter
        if (pwm_cnt_en = '1') then
          if (UNSIGNED(pwm_cnt) >= to_unsigned(PWM_STEPS-1, pwm_cnt'length)) then
            pwm_cnt <= (others => '0');
          else
            pwm_cnt <= STD_LOGIC_VECTOR(UNSIGNED(pwm_cnt) + 1);
          end if;
        end if;

        -- PWM generation (by comparison)
        if (UNSIGNED(pwm_cnt) < UNSIGNED(pwm_duty)) then
          pwm_out <= '1';
        else
          pwm_out <= '0';
        end if;
      end if;
    end if;
  end process p_pwmGen;

  blink_out <= pwm_out;

end archDefault;
