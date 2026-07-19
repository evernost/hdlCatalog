-- ============================================================================
-- Project        : synthChip
-- Module name    : debouncer
-- File name      : debouncer.vhd
-- File type      : VHDL 2008
-- Purpose        : debounce module for push buttons
-- Author         : QuBi (nitrogenium@outlook.fr)
-- Creation date  : August 13th, 2025
-- ----------------------------------------------------------------------------
-- Best viewed with space indentation (2 spaces)
-- ============================================================================

-- ============================================================================
-- DESCRIPTION
-- ============================================================================
-- Simple debouncing module for push buttons, switches etc.
-- The module includes the synchronizing input DFFs.
--
-- It provides various types of outputs:
-- * state output : current state of the push button 
-- * toggle output: state changes on every button press
-- * irq output   : pulse every time an event is detected on the button.
--
-- Known limitations: 
-- None.



-- ============================================================================
-- LIBRARIES
-- ============================================================================
-- Standard libraries
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

-- Project libraries
library work; use work.debouncer_pkg.all;



-- ============================================================================
-- I/O DESCRIPTION
-- ============================================================================
entity debouncer is
generic
(
  RESET_SYNC      : BOOLEAN;                    -- Make the reset synchronous
  RESET_POL       : STD_LOGIC;                  -- Reset active state
  CLOCK_FREQ_MHZ  : REAL;                       -- Clock frequency in MHz
  BLIND_TIME_MS   : REAL := 1.0;                -- Time period (in ms) during which the state of the input is ignored
  IRQ_TRIG_POL    : INTEGER range 0 to 2 := 1;  -- IRQ trigger event: rising edge (0), falling edge (1) or both (2)
  IRQ_DURATION    : INTEGER range 1 to 15 := 1  -- IRQ notification time (in clock cycles)
);
port
( 
  clock         : in STD_LOGIC;
  reset         : in STD_LOGIC; 
  
  button_in     : in STD_LOGIC;
  
  state         : out STD_LOGIC;
  state_n       : out STD_LOGIC;
  toggle        : out STD_LOGIC;

  irq           : out STD_LOGIC;

  bounce_count  : out STD_LOGIC_VECTOR(9 downto 0)
);
end debouncer;



-- ============================================================================
-- ARCHITECTURE
-- ============================================================================
architecture archDefault of debouncer is

  type FSM_STATE_TYPE is (FREEZE, WAIT_EVENT);

  constant TIMER_PRESET : UNSIGNED(31 downto 0) := TO_UNSIGNED(INTEGER(CLOCK_FREQ_MHZ*1000.0*BLIND_TIME_MS)-1, 32);

  signal button_R    : STD_LOGIC;
  signal button_RR   : STD_LOGIC;
  signal button_sync : STD_LOGIC;

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
  -- (3 stages resynchronizer, should be enough for most architectures)
  -- --------------------------------------------------------------------------
  p_sync : process(clock, reset)
  procedure resetProcedure is 
  begin
    button_R    <= '0';
    button_RR   <= '0';
    button_sync <= '0';
  end resetProcedure;
  begin
		if (not(RESET_SYNC) and (reset = RESET_POL)) then
      resetProcedure;
		elsif(clock'event and clock = '1') then
			if (RESET_SYNC and (reset = RESET_POL)) then
        resetProcedure;
      else
        button_R    <= button_in;
        button_RR   <= button_R;
        button_sync <= button_RR;
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
    bounce_count    <= (others => '0');
    bounce_cnt_reg  <= (others => '0');
  end resetProcedure;
  begin
		if (not(RESET_SYNC) and (reset = RESET_POL)) then
      resetProcedure;
		elsif(clock'event and clock = '1') then
			if (RESET_SYNC and (reset = RESET_POL)) then
        resetProcedure;
      else
        case fsm_state is 
          
          -- ------------------------------------------------------------------
          -- WAIT_EVENT State
          -- ------------------------------------------------------------------
          when WAIT_EVENT => 
            if (button_sync /= out_reg) then
              fsm_state <= FREEZE;
              timer     <= STD_LOGIC_VECTOR(TIMER_PRESET);
              
              if (IRQ_TRIG_POL = IRQ_TRIGGER_POL_RISING) then
                if (button_sync = '1') and (out_reg = '0') then
                  event_flag <= '1';
                else 
                  event_flag <= '0';
                end if;
              elsif (IRQ_TRIG_POL = IRQ_TRIGGER_POL_FALLING) then
                if (button_sync = '0') and (out_reg = '1') then
                  event_flag <= '1';
                else 
                  event_flag <= '0';
                end if;
              else
                event_flag <= '1';
              end if;
            else
              -- Nothing happened
            end if;

          -- ------------------------------------------------------------------
          -- FREEZE State
          -- ------------------------------------------------------------------
          when FREEZE => 
            if (timer = STD_LOGIC_VECTOR(to_unsigned(0, timer'length))) then
              fsm_state       <= WAIT_EVENT;
              timer           <= (others => '0');
              out_reg         <= button_sync;
              toggle_reg      <= toggle_reg xor button_sync;
              event_flag      <= '0';
              bounce_count    <= bounce_cnt_reg;
              bounce_cnt_reg  <= (others => '0');
            else
              timer         <= STD_LOGIC_VECTOR(UNSIGNED(timer) - 1);
              event_flag    <= '0';
              bounce_count  <= (others => '0');
              
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
            bounce_count      <= bounce_cnt_reg;
            bounce_cnt_reg  <= (others => '0');

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
    state   <= '0';
    state_n <= '0';
    toggle  <= '0';
  end resetProcedure;
  begin
		if (not(RESET_SYNC) and (reset = RESET_POL)) then
      resetProcedure;
		elsif(clock'event and clock = '1') then
			if (RESET_SYNC and (reset = RESET_POL)) then
        resetProcedure;
      else
        state   <= out_reg;
        state_n <= not(out_reg);
        toggle  <= toggle_reg;
      end if;
    end if;
  end process p_output;



  -- --------------------------------------------------------------------------
  -- PROCESS NAME: IRQ generator
  -- DESCRIPTION: 
  -- Description is TODO.
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
		elsif(clock'event and clock = '1') then
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
