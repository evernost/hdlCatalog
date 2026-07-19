-- ============================================================================
-- Project        : -
-- Module name    : debouncer_pkg
-- File name      : debouncer_pkg.vhd
-- File type      : VHDL 2008
-- Purpose        : package definition for the Debouncer module
-- Author         : QuBi (nitrogenium@outlook.fr)
-- Creation date  : August 11, 2025 at 00:14
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



-- ============================================================================
-- PACKAGE DESCRIPTION
-- ============================================================================
package debouncer_pkg is
  
  -- --------------------------------------------------------------------------
  -- Constants / Types
  -- --------------------------------------------------------------------------
  constant IRQ_TRIGGER_POL_RISING   : INTEGER := 0;
  constant IRQ_TRIGGER_POL_FALLING  : INTEGER := 1;
  constant IRQ_TRIGGER_POL_BOTH     : INTEGER := 2;
  
  -- --------------------------------------------------------------------------
  -- Components
  -- --------------------------------------------------------------------------
  -- None.
  
end package debouncer_pkg;
  
  
  
-- ============================================================================
-- PACKAGE DESCRIPTION
-- ============================================================================
package body debouncer_pkg is 
  
  -- None.
  
end package body;
