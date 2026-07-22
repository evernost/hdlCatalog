-- ============================================================================
-- Project        : hdlCatalog
-- Module name    : debouncer_core
-- File name      : debouncer_core.vhd
-- File type      : VHDL 2008
-- Purpose        : debouncer module for push buttons
-- Author         : QuBi (nitrogenium@outlook.fr)
-- Creation date  : Wednesday, 13 August 2025
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
-- * dout        : current state of the push button 
-- * toggle       : state changes on every button press
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
entity debouncer_core is
generic
(
  RESET_POL       : STD_LOGIC;              -- Reset active state
  RESET_SYNC      : BOOLEAN;                -- True: synchronous reset. False: asynchronous reset
  CLOCK_FREQ_MHZ  : REAL;                   -- System clock frequency (in MHz)
  BLIND_TIME_MS   : REAL;                   -- Time period (in ms) during which the state of the input is ignored
  IRQ_DURATION    : INTEGER range 1 to 15   -- IRQ notification time (in clock cycles)
);
port
( 
  -- System interface
  clock         : in STD_LOGIC;
  reset         : in STD_LOGIC; 
  
  -- Noisy inputs
  din           : in STD_LOGIC;
  
  -- Filtered outputs
  dout          : out STD_LOGIC;                      -- Cleaned output
  dout_n        : out STD_LOGIC;                      -- Cleaned output (complemented)

  -- Byproducts
  toggle        : out STD_LOGIC;                      -- Toggling output  : toggles when 'dout' changes
  irq           : out STD_LOGIC;                      -- IRQ output       : pulses when 'dout' changes
  irq_trig_pol  : in  STD_LOGIC_VECTOR(1 downto 0);   -- Define the event that triggers the IRQ:
                                                      -- * "00": never
                                                      -- * "01": rising edge
                                                      -- * "10": falling edge
                                                      -- * "11": both
  
  -- Observables
  warning       : out STD_LOGIC;                      -- '1' when a bounce occured very close to the end of the last blind time,
                                                      -- which suggests that BLIND_TIME_MS is not sufficient.
  count         : out STD_LOGIC_VECTOR(9 downto 0)    -- Number of bounces detected during the last blind time.
);
end debouncer_core;



-- ============================================================================
-- ARCHITECTURE
-- ============================================================================
architecture archDefault of debouncer_core is

  type FSM_STATE_TYPE is (FREEZE, WAIT_EVENT);

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
    dout   <= '0';
    dout_n <= '0';
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
