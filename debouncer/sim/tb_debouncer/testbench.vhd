-- ============================================================================
-- Project        : -
-- Module name    : testbench
-- File name      : testbench.vhd
-- File type      : VHDL 2008
-- Purpose        : testbench for the debouncer module
-- Author         : QuBi (nitrogenium@outlook.fr)
-- Creation date  : Thursday, 14 August 2025
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
library debouncer_lib; use debouncer_lib.debouncer_pkg.all;



-- ============================================================================
-- I/O DESCRIPTION
-- ============================================================================
entity testbench is
generic
(
  RESET_POL   : STD_LOGIC := '0';
  RESET_SYNC  : BOOLEAN   := TRUE
);
end testbench;



-- ============================================================================
-- ARCHITECTURE
-- ============================================================================
architecture sim of testbench is

  constant CLOCK_FREQ_MHZ : REAL := 100.0;
  constant CLOCK_PERIOD   : TIME := 1 sec / (CLOCK_FREQ_MHZ * 1.0E6);
  
  constant BLIND_TIME_MS  : REAL := 2.0;
  constant CHANNELS       : INTEGER := 3;
  
  signal clock  : STD_LOGIC := '0';
  signal reset  : STD_LOGIC := '0';

  signal btn    : STD_LOGIC_VECTOR(CHANNELS-1 downto 0);
  signal btn_f  : STD_LOGIC_VECTOR(CHANNELS-1 downto 0);
  

begin
  
  -- --------------------------------------------------------------------------
  -- SYSTEM SIGNALS
  -- --------------------------------------------------------------------------
  
  -- Resets
  reset <= RESET_POL, not(RESET_POL) after 111.0 ns;
  
  -- Clocks
  clock <= not(clock) after (CLOCK_PERIOD/2);
  
  btn(0)  <=  '0', 
              '1' after 14ms, 
              '0' after 15ms, 
              '1' after 17ms, 
              '0' after 18ms, 
              '1' after 18.1ms, 
              '0' after 89.7ms, 
              '1' after 94.5ms,
              '0' after 195.0ms;
  btn_irq(1 downto 0) <= "11";

  btn(1)  <=  '1', 
              '0' after 0.4ms, 
              '1' after 0.9ms, 
              '0' after 1.4ms, 
              '1' after 1.45ms, 
              '0' after 1.47ms, 
              '1' after 89.7ms, 
              '0' after 94.5ms,
              '1' after 95.7ms;
  btn_irq(3 downto 2) <= "10";

  btn(2)  <=  '1', 
              '0' after 0.4ms, 
              '1' after 0.9ms, 
              '0' after 1.4ms, 
              '1' after 1.45ms, 
              '0' after 1.47ms, 
              '1' after 89.7ms, 
              '0' after 94.5ms,
              '1' after 95.7ms;
  btn_irq(5 downto 4) <= "10";
  
  
  
  -- --------------------------------------------------------------------------
  -- DUT
  -- --------------------------------------------------------------------------
  dut_debouncer_0 : entity debouncer_lib.debouncer(archDefault)  
  generic map
  (
    RESET_POL       => RESET_POL,
    RESET_SYNC      => RESET_SYNC,
    CLOCK_FREQ_MHZ  => 100.0,
    CHANNELS        => CHANNELS,
    BLIND_TIME_MS   => 2.0,
    IRQ_DURATION    => 2
  )
  port map
  ( 
    -- System interface
    clock         => clock,
    reset         => reset,
    
    -- Noisy inputs
    din           => btn,

    -- Filtered outputs
    dout          => btn_f,
    dout_n        => btn_f_n,

    -- Byproducts
    toggle        => btn_toggle,
    irq           => btn_irq,
    irq_trig_pol  => btn_irq_trig_pol
  );
  
end sim;
