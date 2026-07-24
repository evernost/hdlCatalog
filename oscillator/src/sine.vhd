-- ============================================================================
-- Project        : hdlCatalog/sine
-- Module name    : sine
-- File name      : sine.vhd
-- File type      : VHDL 2008
-- Purpose        : sinewave generator
-- Author         : QuBi (nitrogenium@outlook.fr)
-- Creation date  : Thursday, 23 July 2026
-- ----------------------------------------------------------------------------
-- Best viewed with space indentation (2 spaces)
-- ============================================================================

-- ============================================================================
-- DESCRIPTION
-- ============================================================================
-- Continuous sinewave generator.
--
-- * The instantaneous frequency is specified in Hz in fixed point format.
-- * Only one ROM is synthesized for all channels. 
--   However, the more channels are needed, the higher the generation latency.
-- * The ROM stores a quarter of a full sinewave.
-- 
-- NOTE:
-- ROM size, output width etc. must be defined in the python script
-- 'makeSineROM.py'. 
-- The package definition and the top level will be derived automatically.






-- ============================================================================
-- LIBRARIES
-- ============================================================================
-- Standard libraries
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

-- Project libraries
library work; use work.sine_pkg.all;



-- ============================================================================
-- I/O DESCRIPTION
-- ============================================================================
entity sine is
generic
(
  RESET_POL       : STD_LOGIC;    -- Reset active state
  RESET_SYNC      : BOOLEAN;      -- True: synchronous reset. False: asynchronous reset
  SAMPLE_RATE_KHZ : REAL          -- Sampling frequency (in kHz)
  N_CHANNELS      : INTEGER       -- Number of simultaneous outputs
);
port
( 
  -- System interface
  clock     : in STD_LOGIC;
  reset     : in STD_LOGIC; 
  
  frequency : in  freq_array_t(0 to CHANNELS-1)

  req       : in  STD_LOGIC;
  valid     : out STD_LOGIC;
  output    : out out_array_t(0 to CHANNELS-1)
);
end sine;



-- ============================================================================
-- ARCHITECTURE
-- ============================================================================
architecture archDefault of sine is

  

  constant TIMER_PRESET : UNSIGNED(31 downto 0) := TO_UNSIGNED(INTEGER(CLOCK_FREQ_MHZ*1000.0*BLIND_TIME_MS)-1, 32);

  signal din_R    : STD_LOGIC;
  signal din_RR   : STD_LOGIC;
  signal din_sync : STD_LOGIC;

  signal timer : STD_LOGIC_VECTOR(31 downto 0);

  signal fsm_state  : FSM_STATE_TYPE;
  signal out_reg    : STD_LOGIC;
  signal toggle_reg : STD_LOGIC;

  signal event_flag     : STD_LOGIC;
  signal irq_en         : STD_LOGIC;
  signal irq_cycle_cnt  : STD_LOGIC_VECTOR(3 downto 0);

  signal bounce_cnt_reg : STD_LOGIC_VECTOR(9 downto 0);
  
begin

  -- --------------------------------------------------------------------------
  -- PROCESS NAME: resynchronizer
  -- DESCRIPTION: 
  -- Bring back the asynchronous input to the synchronous domain.
  -- (3 stages resynchronizer: should be enough for most architectures)
  -- --------------------------------------------------------------------------
  p_sync : process(clock, reset)
  procedure resetProcedure is 
  begin
    din_R     <= '0';
    din_RR    <= '0';
    din_sync  <= '0';
  end resetProcedure;
  begin
		if (not(RESET_SYNC) and (reset = RESET_POL)) then
      resetProcedure;
		elsif (clock'event and (clock = '1')) then
			if (RESET_SYNC and (reset = RESET_POL)) then
        resetProcedure;
      else
        din_R    <= din;
        din_RR   <= din_R;
        din_sync <= din_RR;
      end if;
    end if;
  end process p_sync;



  -- --------------------------------------------------------------------------
  -- PROCESS NAME: debouncing FSM
  -- DESCRIPTION: 
  -- Description is TODO.
  -- --------------------------------------------------------------------------
  p_debounce : process(clock, reset)
  procedure resetProcedure is 
  begin
    fsm_state       <= WAIT_EVENT;
    timer           <= (others => '0');
    event_flag      <= '0';
    out_reg         <= '0';
    toggle_reg      <= '0';
    count           <= (others => '0');
    bounce_cnt_reg  <= (others => '0');
    warning_reg     <= '0';
  end resetProcedure;
  begin
		if (not(RESET_SYNC) and (reset = RESET_POL)) then
      resetProcedure;
		elsif (clock'event and (clock = '1')) then
			if (RESET_SYNC and (reset = RESET_POL)) then
        resetProcedure;
      else
        case fsm_state is 
          
          -- ------------------------------------------------------------------
          -- WAIT_EVENT State
          -- ------------------------------------------------------------------
          when WAIT_EVENT => 
            if (din_sync /= out_reg) then
              fsm_state   <= FREEZE;
              timer       <= STD_LOGIC_VECTOR(TIMER_PRESET);
              event_flag  <= '0';
              
              if (irq_trig_pol(0) = '1') then
                if ((din_sync = '1') and (out_reg = '0')) then
                  event_flag <= '1';
                end if;
              end if;
              
              if (irq_trig_pol(1) = '1') then
                if ((din_sync = '0') and (out_reg = '1')) then
                  event_flag <= '1';
                end if;
              end if;
            
            else
              -- Nothing happened, keep waiting.
            end if;

          -- ------------------------------------------------------------------
          -- FREEZE State
          -- ------------------------------------------------------------------
          when FREEZE => 
            if (timer = STD_LOGIC_VECTOR(to_unsigned(0, timer'length))) then
              fsm_state       <= WAIT_EVENT;
              timer           <= (others => '0');
              out_reg         <= din_sync;
              toggle_reg      <= toggle_reg xor din_sync;
              event_flag      <= '0';
              count           <= bounce_cnt_reg;
              bounce_cnt_reg  <= (others => '0');
            else
              timer         <= STD_LOGIC_VECTOR(UNSIGNED(timer) - 1);
              event_flag    <= '0';
              count  <= (others => '0');
              
              if FALSE then
                bounce_cnt_reg <= STD_LOGIC_VECTOR(UNSIGNED(bounce_cnt_reg)+1);
              end if;

            end if;

          -- ------------------------------------------------------------------
          -- Exceptions
          -- ------------------------------------------------------------------
          when others =>
            fsm_state         <= WAIT_EVENT;
            timer             <= (others => '0');
            event_flag        <= '0';
            out_reg           <= '0';
            count             <= bounce_cnt_reg;
            bounce_cnt_reg    <= (others => '0');

        end case;
      end if;
    end if;
  end process p_debounce;



  -- --------------------------------------------------------------------------
  -- PROCESS NAME: output
  -- DESCRIPTION: 
  -- Description is TODO.
  -- --------------------------------------------------------------------------
  p_output : process(clock, reset)
  procedure resetProcedure is 
  begin
    dout    <= '0';
    dout_n  <= '0';
    toggle  <= '0';
  end resetProcedure;
  begin
		if (not(RESET_SYNC) and (reset = RESET_POL)) then
      resetProcedure;
		elsif (clock'event and (clock = '1')) then
			if (RESET_SYNC and (reset = RESET_POL)) then
        resetProcedure;
      else
        dout    <= out_reg;
        dout_n  <= not(out_reg);
        toggle  <= toggle_reg;
      end if;
    end if;
  end process p_output;



  -- --------------------------------------------------------------------------
  -- PROCESS NAME: IRQ generator
  -- DESCRIPTION: 
  -- Generates the IRQ signals from the FSM.
  -- --------------------------------------------------------------------------
  p_event : process(clock, reset)
  procedure resetProcedure is 
  begin
    irq_en        <= '0';
    irq_cycle_cnt <= (others => '0');
    irq           <= '0';
  end resetProcedure;
  begin
		if (not(RESET_SYNC) and (reset = RESET_POL)) then
      resetProcedure;
		elsif (clock'event and (clock = '1')) then
			if (RESET_SYNC and (reset = RESET_POL)) then
        resetProcedure;
      else
        if (irq_en = '0') then
          if (event_flag = '1') then
            irq           <= '1';
            irq_en        <= '1';
            irq_cycle_cnt <= STD_LOGIC_VECTOR(UNSIGNED(irq_cycle_cnt) + 1);
          end if;
        else
          if (irq_cycle_cnt = STD_LOGIC_VECTOR(to_unsigned(IRQ_DURATION, irq_cycle_cnt'length))) then
            irq           <= '0';
            irq_en        <= '0';
            irq_cycle_cnt <= (others => '0');
          else
            irq_cycle_cnt <= STD_LOGIC_VECTOR(UNSIGNED(irq_cycle_cnt) + 1);
          end if;
        end if;
      end if;
    end if;
  end process p_event;



end archDefault;
