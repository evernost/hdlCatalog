-- ============================================================================
-- Project        : -
-- Module name    : debouncer
-- File name      : debouncer.vhd
-- File type      : VHDL 2008
-- Purpose        : debouncer module for push buttons
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
  RESET_SYNC      : BOOLEAN;                -- True: synchronous reset. False: asynchronous reset
  RESET_POL       : STD_LOGIC;              -- Reset active state
  CLOCK_FREQ_MHZ  : REAL;                   -- System clock frequency (in MHz)
  CHANNELS        : INTEGER;                -- Number of channels to debounce
  BLIND_TIME_MS   : REAL;                   -- Time period (in ms) during which the state of the input is ignored
  IRQ_DURATION    : INTEGER range 1 to 15   -- IRQ notification time (in clock cycles)
);
port
( 
  -- System interface
  clock         : in STD_LOGIC;
  reset         : in STD_LOGIC; 
  
  -- Noisy inputs
  din           : in STD_LOGIC_VECTOR(CHANNELS-1 downto 0);

  -- Filtered outputs
  dout          : out STD_LOGIC_VECTOR(CHANNELS-1 downto 0);      -- Cleaned output
  dout_n        : out STD_LOGIC_VECTOR(CHANNELS-1 downto 0);      -- Cleaned output (complemented)

  -- Byproducts
  toggle        : out STD_LOGIC_VECTOR(CHANNELS-1 downto 0);      -- Toggling output  : toggles when 'dout' changes
  irq           : out STD_LOGIC_VECTOR(CHANNELS-1 downto 0);      -- IRQ output       : pulses when 'dout' changes
  irq_trig_pol  : in  STD_LOGIC_VECTOR((2*CHANNELS)-1 downto 0)   -- Define the event that triggers the IRQ:
                                                                  -- - "00": never
                                                                  -- - "01": rising edge
                                                                  -- - "10": falling edge
                                                                  -- - "11": both
);
end debouncer;



-- ============================================================================
-- ARCHITECTURE
-- ============================================================================
architecture archDefault of debouncer is



begin

  gen_instances : for i in 0 to (CHANNELS-1) generate
  begin
    u_debouncer : entity debouncer_lib.debouncer(archDefault)
    generic map
    (
      RESET_POL       => RESET_POL,
      RESET_SYNC      => RESET_SYNC,
      CLOCK_FREQ_MHZ  => CLOCK_FREQ_MHZ,
      BLIND_TIME_MS   => BLIND_TIME_MS,
      IRQ_DURATION    => IRQ_DURATION
    )
    port map
    ( 
      clock         => clock,
      reset         => reset,
  
      din           => din(i)
  
      dout          => dout(i),
      dout_n        => dout_n(i),

      toggle        => toggle(i)

      irq           => irq(i),
      irq_trig_pol  => irq_trig_pol((2*i+1) downto (2*i))

      count         => open
    );
  end generate;

end archDefault;
