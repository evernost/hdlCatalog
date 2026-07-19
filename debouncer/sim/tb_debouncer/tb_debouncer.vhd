-- ============================================================================
-- Project        : synthChip
-- Module name    : tb_debouncer
-- File name      : tb_debouncer.vhd
-- File type      : VHDL 2008
-- Purpose        : testbench for the debouncer
-- Author         : QuBi (nitrogenium@outlook.fr)
-- Creation date  : August 14th, 2025
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
entity tb_debouncer is
generic
(
  RESET_POL       : STD_LOGIC := '0';
  RESET_SYNC      : BOOLEAN := TRUE;
  CLOCK_FREQ_MHZ  : REAL := 100.0;
  BLIND_TIME_MS   : REAL := 20.0;
  IRQ_DURATION    : INTEGER range 1 to 15 := 1;
  IRQ_TRIG_POL    : INTEGER range 0 to 2 := IRQ_TRIGGER_POL_RISING
);
end tb_debouncer;



-- ============================================================================
-- ARCHITECTURE
-- ============================================================================
architecture archDefault of tb_debouncer is

  constant clock_period : TIME := 1 sec / (CLOCK_FREQ_MHZ * 1.0E6);
  
  signal clock  : STD_LOGIC := '0';
  signal reset  : STD_LOGIC := '0';

  signal button   : STD_LOGIC;
  signal state    : STD_LOGIC;
  signal state_n  : STD_LOGIC;
  signal toggle   : STD_LOGIC;
  signal irq      : STD_LOGIC;

begin
  
  -- --------------------------------------------------------------------------
  -- DUT (debouncer)
  -- --------------------------------------------------------------------------
  dut_debouncer_0 : entity debouncer_lib.debouncer(archDefault)
  generic map
  (
    RESET_POL       => RESET_POL,
    RESET_SYNC      => RESET_SYNC,
    CLOCK_FREQ_MHZ  => CLOCK_FREQ_MHZ,
    BLIND_TIME_MS   => BLIND_TIME_MS,
    IRQ_DURATION    => IRQ_DURATION,
    IRQ_TRIG_POL    => IRQ_TRIG_POL
  )
  port map
  ( 
    clock     => clock,
    reset     => reset,
    
    button_in => button,
    
    state     => state,
    state_n   => state_n,
    toggle    => toggle,

    irq       => irq
  );

  -- Resets
  reset <= RESET_POL, not(RESET_POL) after 111.0 ns;
  
  -- Clocks
  clock <= not(clock) after (clock_period/2);
  
  button <= '0', 
            '1' after 14ms, 
            '0' after 15ms, 
            '1' after 17ms, 
            '0' after 18ms, 
            '1' after 18.1ms, 
            '0' after 89.7ms, 
            '1' after 94.5ms,
            '0' after 195.0ms;
  
  
end archDefault;
