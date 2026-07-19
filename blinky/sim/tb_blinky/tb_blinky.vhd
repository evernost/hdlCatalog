-- ============================================================================
-- Project        : synthChip
-- Module name    : tb_blinky
-- File name      : tb_blinky.vhd
-- File type      : VHDL 2008
-- Purpose        : testbench for the blinky
-- Author         : QuBi (nitrogenium@outlook.fr)
-- Creation date  : August 13th, 2025
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
entity tb_blinky is
generic
(
  RESET_POL   : STD_LOGIC := '0';
  RESET_SYNC  : BOOLEAN   := TRUE
);
end tb_blinky;



-- ============================================================================
-- ARCHITECTURE
-- ============================================================================
architecture archDefault of tb_blinky is
  
  constant CLOCK_PERIOD : TIME := 1 sec / (CLOCK_FREQ_MHZ * 1.0E6);

  constant BLINK_FREQ_1HZ   : STD_LOGIC_VECTOR(15 downto 0) := STD_LOGIC_VECTOR(to_unsigned(1000, 16));
  constant BLINK_FREQ_4HZ   : STD_LOGIC_VECTOR(15 downto 0) := STD_LOGIC_VECTOR(to_unsigned(250, 16));
  constant BLINK_FREQ_10HZ  : STD_LOGIC_VECTOR(15 downto 0) := STD_LOGIC_VECTOR(to_unsigned(100, 16));

  signal blink_period : STD_LOGIC_VECTOR(15 downto 0);

  signal clock  : STD_LOGIC := '0';
  signal reset  : STD_LOGIC := '0';

  signal blink  : STD_LOGIC;

begin
  
  -- --------------------------------------------------------------------------
  -- DUT (blinky)
  -- --------------------------------------------------------------------------
  dut_blinky_0 : entity blinky_lib.blinky(archDefault)
  generic map
  (
    RESET_POL       => RESET_POL,
    RESET_SYNC      => RESET_SYNC,
    CLOCK_FREQ_MHZ  => CLOCK_FREQ_MHZ
  )
  port map
  ( 
    clock             => clock,
    reset             => reset,
    
    blink_period_ms   => blink_period;
    pulse_duration_ms => 

    pattern_sel       => pattern,

    blink_out         => blink
  );



  -- Resets 
  reset <= RESET_POL, not(RESET_POL) after 111.0 ns;
  
  -- Clocks
  clock <= not(clock) after (clock_period/2);
  


  blink_period <= BLINK_FREQ_1HZ,
                  BLINK_FREQ_10HZ,  after 140ms,
                  BLINK_FREQ_4HZ,   after 1100ms,
                  BLINK_FREQ_1HZ,   after 2400ms;


  pattern <= PATTERN_SMOOTH_TOGGLE;


end archDefault;
