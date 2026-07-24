-- ============================================================================
-- Project        : pixelPusher
-- Module name    : vesa_line_fifo
-- File name      : vesa_line_fifo.vhd
-- File type      : VHDL 2008
-- Purpose        : 
-- Author         : QuBi (nitrogenium@outlook.fr)
-- Creation date  : Sunday, 19 July 2026
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

library xpm; use xpm.vcomponents.all;

-- Project libraries
-- library work; use work.pixel_pusher_pkg.all;
-- None.



-- ============================================================================
-- I/O DESCRIPTION
-- ============================================================================
entity vesa_line_fifo is
generic
(
  RESET_SYNC  : BOOLEAN;
  RESET_POL   : STD_LOGIC;
  LINE_SIZE   : INTEGER;
  DIN_SIZE    : INTEGER;
  DOUT_SIZE   : INTEGER
);
port
( 
  -- System
  clock       : in STD_LOGIC;
  reset       : in STD_LOGIC;

  -- Write interface
  data_in     : in STD_LOGIC_VECTOR(DIN_SIZE-1 downto 0);
  push        : in STD_LOGIC;
  write_en    : in STD_LOGIC;
  
  -- Read interface
  data_out    : out STD_LOGIC_VECTOR(DOUT_SIZE-1 downto 0);
  pop         : in STD_LOGIC;
  
  -- Status
  empty       : out STD_LOGIC;
  full        : out STD_LOGIC;
  data_count  : out STD_LOGIC_VECTOR(11 downto 0)
);
end vesa_line_fifo;



-- ============================================================================
-- ARCHITECTURE
-- ============================================================================
architecture archDefault of vesa_line_fifo is

  assert (LINE_SIZE <= 2048) report "The line size must be less than 2048." severity error;

begin

  

-- +---------------------------------------------------------------------------------------------------------------------+
-- | Parameter name       | Data type          | Restrictions, if applicable                                             |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Description                                                                                                         |
-- +---------------------------------------------------------------------------------------------------------------------+
-- +---------------------------------------------------------------------------------------------------------------------+
-- | CASCADE_HEIGHT       | Integer            | Range: 0 - 64. Default value = 0.                                       |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | 0: No Cascade Height, Enables Vivado Synthesis to choose.                                                           |
-- | 1 or more - Vivado Synthesis sets the specified value as Cascade Height.                                            |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | DOUT_RESET_VALUE     | String             | Default value = 0.                                                      |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Reset value of read data path.                                                                                      |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | ECC_MODE             | String             | Allowed values: no_ecc, en_ecc. Default value = no_ecc.                 |
-- |---------------------------------------------------------------------------------------------------------------------|
-- |                                                                                                                     |
-- |   "no_ecc": Disables ECC                                                                                            |
-- |   "en_ecc": Enables both ECC Encoder and Decoder                                                                    |
-- |                                                                                                                     |
-- | NOTE: ECC_MODE must be "no_ecc" if you set FIFO_MEMORY_TYPE to "auto" Violating this might result incorrect behavior.|
-- +---------------------------------------------------------------------------------------------------------------------+
-- | EN_SIM_ASSERT_ERR    | String             | Default value = warning.                                                |
-- |---------------------------------------------------------------------------------------------------------------------|
-- |                                                                                                                     |
-- |   "warning": Report warning message for FIFO overflow and underflow in simulation.                                  |
-- |   "error": Report error message for FIFO overflow and underflow in simulation.                                      |
-- |   "fatal": Report fatal message for FIFO overflow and underflow in simulation.                                      |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | FIFO_MEMORY_TYPE     | String             | Allowed values: auto, block, distributed, ultra. Default value = auto.  |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Specifies the fifo memory primitive (resource type) to use.                                                         |
-- |                                                                                                                     |
-- |   "auto": Enables Vivado Synthesis to choose                                                                        |
-- |   "block": Block RAM FIFO                                                                                           |
-- |   "distributed": Distributed RAM FIFO                                                                               |
-- |   "ultra": URAM FIFO                                                                                                |
-- |                                                                                                                     |
-- | NOTE: Selecting Block RAM or UltraRAM specific features, like ECC or Asymmetry, with FIFO_MEMORY_TYPE set to "auto" might cause a behavior mismatch.|
-- +---------------------------------------------------------------------------------------------------------------------+
-- | FIFO_READ_LATENCY    | Integer            | Range: 0 - 100. Default value = 1.                                      |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Number of output register stages in the read data path.                                                             |
-- |                                                                                                                     |
-- |   If READ_MODE = "fwft", then the only applicable value is 0                                                        |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | FIFO_WRITE_DEPTH     | Integer            | Range: 16 - 4194304. Default value = 2048.                              |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Defines the FIFO Write Depth, must be power of two.                                                                 |
-- |                                                                                                                     |
-- |   In standard READ_MODE, the effective depth = FIFO_WRITE_DEPTH                                                     |
-- |   In First-Word-Fall-Through READ_MODE, the effective depth = FIFO_WRITE_DEPTH+2                                    |
-- |                                                                                                                     |
-- | NOTE: The maximum FIFO size (width x depth) has a limit of 150-Megabits.                                            |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | FULL_RESET_VALUE     | Integer            | Range: 0 - 1. Default value = 0.                                        |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Sets full, almost_full and prog_full to FULL_RESET_VALUE during reset                                               |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | PROG_EMPTY_THRESH    | Integer            | Range: 3 - 4194304. Default value = 10.                                 |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Specifies the minimum number of read words in the FIFO at or below which prog_empty asserts.                        |
-- |                                                                                                                     |
-- |   Min_Value = 3 + (READ_MODE_VAL*2)                                                                                 |
-- |   Max_Value = (FIFO_WRITE_DEPTH-3) - (READ_MODE_VAL*2)                                                              |
-- |                                                                                                                     |
-- | If READ_MODE = "std", then READ_MODE_VAL = 0; Otherwise READ_MODE_VAL = 1.                                          |
-- | NOTE: The default threshold value depends on default FIFO_WRITE_DEPTH value. If FIFO_WRITE_DEPTH value              |
-- | changes, verify the threshold value is within the valid range though the programmable flags are not used.           |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | PROG_FULL_THRESH     | Integer            | Range: 3 - 4194301. Default value = 10.                                 |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Specifies the maximum number of write words in the FIFO at or above which prog_full asserts.                        |
-- |                                                                                                                     |
-- |   Min_Value = 3 + (READ_MODE_VAL*2*(FIFO_WRITE_DEPTH/FIFO_READ_DEPTH))                                              |
-- |   Max_Value = (FIFO_WRITE_DEPTH-3) - (READ_MODE_VAL*2*(FIFO_WRITE_DEPTH/FIFO_READ_DEPTH))                           |
-- |                                                                                                                     |
-- | If READ_MODE = "std", then READ_MODE_VAL = 0; Otherwise READ_MODE_VAL = 1.                                          |
-- | NOTE: The default threshold value depends on default FIFO_WRITE_DEPTH value. If FIFO_WRITE_DEPTH value              |
-- | changes, verify the threshold value is within the valid range though the programmable flags are not used.           |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | RD_DATA_COUNT_WIDTH  | Integer            | Range: 1 - 23. Default value = 1.                                       |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Specifies the width of rd_data_count. To reflect the correct value, the width must be log2(FIFO_READ_DEPTH)+1.      |
-- |                                                                                                                     |
-- |   FIFO_READ_DEPTH = FIFO_WRITE_DEPTH*WRITE_DATA_WIDTH/READ_DATA_WIDTH                                               |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | READ_DATA_WIDTH      | Integer            | Range: 1 - 4096. Default value = 32.                                    |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Defines the width of the read data port, dout.                                                                      |
-- |                                                                                                                     |
-- |   Write and read width aspect ratio must be 1:1, 1:2, 1:4, 1:8, 8:1, 4:1, and 2:1.                                  |
-- |   For example, if WRITE_DATA_WIDTH is 32, then the READ_DATA_WIDTH must be 32, 64, 128, 256, 16, 8, 4.              |
-- |                                                                                                                     |
-- | NOTE:                                                                                                               |
-- |                                                                                                                     |
-- |   READ_DATA_WIDTH must be equal to WRITE_DATA_WIDTH if you set FIFO_MEMORY_TYPE to "auto" Violating this might result incorrect behavior. |
-- |   The maximum FIFO size (width x depth) has a limit of 150-Megabits.                                                |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | READ_MODE            | String             | Allowed values: std, fwft. Default value = std.                         |
-- |---------------------------------------------------------------------------------------------------------------------|
-- |                                                                                                                     |
-- |   "std": standard read mode                                                                                         |
-- |   "fwft": First-Word-Fall-Through read mode                                                                         |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | SIM_ASSERT_CHK       | Integer            | Range: 0 - 1. Default value = 0.                                        |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | 0: Disable simulation message reporting. This does not report messages related to potential misuse.                 |
-- | 1: Enable simulation message reporting. This reports messages related to potential misuse.                          |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | USE_ADV_FEATURES     | String             | Default value = 0707.                                                   |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Enables data_valid, almost_empty, rd_data_count, prog_empty, underflow, wr_ack, almost_full, wr_data_count,         |
-- | prog_full, overflow features.                                                                                       |
-- |                                                                                                                     |
-- |   Setting USE_ADV_FEATURES[0] to 1 enables overflow flag; Default value of this bit is 1                            |
-- |   Setting USE_ADV_FEATURES[1] to 1 enables prog_full flag; Default value of this bit is 1                           |
-- |   Setting USE_ADV_FEATURES[2] to 1 enables wr_data_count; Default value of this bit is 1                            |
-- |   Setting USE_ADV_FEATURES[3] to 1 enables almost_full flag; Default value of this bit is 0                         |
-- |   Setting USE_ADV_FEATURES[4] to 1 enables wr_ack flag; Default value of this bit is 0                              |
-- |   Setting USE_ADV_FEATURES[8] to 1 enables underflow flag; Default value of this bit is 1                           |
-- |   Setting USE_ADV_FEATURES[9] to 1 enables prog_empty flag; Default value of this bit is 1                          |
-- |   Setting USE_ADV_FEATURES[10] to 1 enables rd_data_count; Default value of this bit is 1                           |
-- |   Setting USE_ADV_FEATURES[11] to 1 enables almost_empty flag; Default value of this bit is 0                       |
-- |   Setting USE_ADV_FEATURES[12] to 1 enables data_valid flag; Default value of this bit is 0                         |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | WAKEUP_TIME          | Integer            | Range: 0 - 2. Default value = 0.                                        |
-- |---------------------------------------------------------------------------------------------------------------------|
-- |                                                                                                                     |
-- |   0 - Disable sleep                                                                                                 |
-- |   2 - Use Sleep Pin                                                                                                 |
-- |                                                                                                                     |
-- | NOTE: WAKEUP_TIME must be 0 if you set FIFO_MEMORY_TYPE to "auto" Violating this might result incorrect behavior.   |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | WRITE_DATA_WIDTH     | Integer            | Range: 1 - 4096. Default value = 32.                                    |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Defines the width of the write data port, din.                                                                      |
-- |                                                                                                                     |
-- |   Write and read width aspect ratio must be 1:1, 1:2, 1:4, 1:8, 8:1, 4:1, and 2:1.                                  |
-- |   For example, if WRITE_DATA_WIDTH is 32, then the READ_DATA_WIDTH must be 32, 64, 128, 256, 16, 8, 4.              |
-- |                                                                                                                     |
-- | NOTE:                                                                                                               |
-- |                                                                                                                     |
-- |   WRITE_DATA_WIDTH must be equal to READ_DATA_WIDTH if you set FIFO_MEMORY_TYPE to "auto" Violating this might result incorrect behavior.|
-- |   The maximum FIFO size (width x depth) has a limit of 150-Megabits.                                                |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | WR_DATA_COUNT_WIDTH  | Integer            | Range: 1 - 23. Default value = 1.                                       |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Specifies the width of wr_data_count. To reflect the correct value, the width must be log2(FIFO_WRITE_DEPTH)+1.     |
-- +---------------------------------------------------------------------------------------------------------------------+

-- Port usage table, organized as follows:
-- +---------------------------------------------------------------------------------------------------------------------+
-- | Port name      | Direction | Size, in bits                         | Domain  | Sense       | Handling if unused     |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Description                                                                                                         |
-- +---------------------------------------------------------------------------------------------------------------------+
-- +---------------------------------------------------------------------------------------------------------------------+
-- | almost_empty   | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Almost Empty : When asserted, this signal indicates that the FIFO can provide only one more read before it goes to  |
-- | empty.                                                                                                              |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | almost_full    | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Almost Full: When asserted, this signal indicates that the FIFO can perform only one more write before it is full.  |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | data_valid     | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Read Data Valid: When asserted, this signal indicates that valid data appears on the output bus (dout).             |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | dbiterr        | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Double Bit Error: Indicates that the ECC decoder detected a double-bit error and data in the FIFO core becomes corrupted.|
-- +---------------------------------------------------------------------------------------------------------------------+
-- | din            | Input     | WRITE_DATA_WIDTH                      | wr_clk  | NA          | Required               |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Write Data: The input data bus used when writing the FIFO.                                                          |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | dout           | Output    | READ_DATA_WIDTH                       | wr_clk  | NA          | Required               |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Read Data: This drives the output data bus when reading the FIFO.                                                   |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | empty          | Output    | 1                                     | wr_clk  | Active-high | Required               |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Empty Flag: When asserted, this signal indicates that the FIFO is empty.                                            |
-- | The FIFO ignores read requests when the FIFO is empty, initiating a read while empty is not destructive to the FIFO.|
-- +---------------------------------------------------------------------------------------------------------------------+
-- | full           | Output    | 1                                     | wr_clk  | Active-high | Required               |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Full Flag: When asserted, this signal indicates that the FIFO is full.                                              |
-- | The FIFO ignores write requests when the FIFO is full, initiating a write when the FIFO is full is not destructive  |
-- | to the contents of the FIFO.                                                                                        |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | injectdbiterr  | Input     | 1                                     | wr_clk  | Active-high | Tie to 1'b0            |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Double Bit Error Injection: Injects a double bit error if using the ECC feature on block RAMs or                    |
-- | UltraRAM macros.                                                                                                    |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | injectsbiterr  | Input     | 1                                     | wr_clk  | Active-high | Tie to 1'b0            |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Single Bit Error Injection: Injects a single bit error if using the ECC feature on block RAMs or                    |
-- | UltraRAM macros.                                                                                                    |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | overflow       | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Overflow: This signal indicates that a write request (wren) during the prior clock cycle was rejected,              |
-- | because the FIFO is full. Overflowing the FIFO is not destructive to the contents of the FIFO.                      |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | prog_empty     | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Programmable Empty: This signal asserts when the number of words in the FIFO is less than or equal                  |
-- | to the programmable empty threshold value.                                                                          |
-- | It de-asserts when the number of words in the FIFO exceeds the programmable empty threshold value.                  |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | prog_full      | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Programmable Full: This signal asserts when the number of words in the FIFO is greater than or equal                |
-- | to the programmable full threshold value.                                                                           |
-- | It de-asserts when the number of words in the FIFO is less than the programmable full threshold value.              |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | rd_data_count  | Output    | RD_DATA_COUNT_WIDTH                   | wr_clk  | NA          | DoNotCare              |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Read Data Count: This bus indicates the number of words read from the FIFO.                                         |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | rd_en          | Input     | 1                                     | wr_clk  | Active-high | Required               |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Read Enable: If the FIFO is not empty, asserting this signal reads data (on dout) from the FIFO.                    |
-- |                                                                                                                     |
-- |   Hold this signal active-Low when rd_rst_busy is active-High.                                                      |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | rd_rst_busy    | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Read Reset Busy: Active-High indicator that the FIFO read domain remains in a reset state.                          |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | rst            | Input     | 1                                     | wr_clk  | Active-high | Required               |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Reset: Must be synchronous to wr_clk. The clocks can be unstable at the time of applying reset, but release reset only after the clocks is/are stable.|
-- +---------------------------------------------------------------------------------------------------------------------+
-- | sbiterr        | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Single Bit Error: Indicates that the ECC decoder detected and fixed a single-bit error.                             |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | sleep          | Input     | 1                                     | NA      | Active-high | Tie to 1'b0            |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Dynamic power saving- If sleep is High, the memory/fifo block is in power saving mode.                              |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | underflow      | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Underflow: Indicates that the read request (rd_en) during the previous clock cycle was rejected                     |
-- | because the FIFO is empty. Under flowing the FIFO is not destructive to the FIFO.                                   |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | wr_ack         | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Write Acknowledge: This signal indicates that a write request (wr_en) during the prior clock cycle succeeded.       |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | wr_clk         | Input     | 1                                     | NA      | Rising edge | Required               |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Write clock: Used for write operation. wr_clk must be a free running clock.                                         |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | wr_data_count  | Output    | WR_DATA_COUNT_WIDTH                   | wr_clk  | NA          | DoNotCare              |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Write Data Count: This bus indicates the number of words written into the FIFO.                                     |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | wr_en          | Input     | 1                                     | wr_clk  | Active-high | Required               |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Write Enable: If the FIFO is not full, asserting this signal writes data (on din) to the FIFO                       |
-- |                                                                                                                     |
-- |   Hold this signal active-Low when rst or wr_rst_busy or rd_rst_busy is active-High                                 |
-- +---------------------------------------------------------------------------------------------------------------------+
-- | wr_rst_busy    | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
-- |---------------------------------------------------------------------------------------------------------------------|
-- | Write Reset Busy: Active-High indicator that the FIFO write domain remains in a reset state.                        |
-- +---------------------------------------------------------------------------------------------------------------------+


-- xpm_fifo_sync : In order to incorporate this function into the design,
--     VHDL      : the following instance declaration needs to be placed
--   instance    : in the body of the design code.  The instance name
--  declaration  : (xpm_fifo_sync_inst) and/or the port declarations after the
--     code      : "=>" declaration maybe changed to properly reference and
--               : connect this function to the design.  All inputs and outputs
--               : must be connected.

--    Library    : In addition to adding the instance declaration, a use
--  declaration  : statement for the UNISIM.vcomponents library needs to be
--      for      : added before the entity declaration.  This library
--    Xilinx     : contains the component declarations for all Xilinx
--  primitives   : primitives and points to the models that will be used
--               : for simulation.

  fifo_0 : xpm_fifo_sync
  generic map
  (
    CASCADE_HEIGHT      => 0,
    DOUT_RESET_VALUE    => "0",
    ECC_MODE            => "no_ecc",
    EN_SIM_ASSERT_ERR   => "warning",
    FIFO_MEMORY_TYPE    => "auto",
    FIFO_READ_LATENCY   => 1,
    FIFO_WRITE_DEPTH    => 2048,
    FULL_RESET_VALUE    => 0,
    PROG_EMPTY_THRESH   => 10,
    PROG_FULL_THRESH    => data_count,
    RD_DATA_COUNT_WIDTH => 1,
    READ_DATA_WIDTH     => DOUT_SIZE,
    READ_MODE           => "std",
    SIM_ASSERT_CHK      => 1,
    USE_ADV_FEATURES    => "0707",
    WAKEUP_TIME         => 0,
    WRITE_DATA_WIDTH    => DIN_SIZE,
    WR_DATA_COUNT_WIDTH => 12         -- To reflect the correct value, the width must be log2(FIFO_WRITE_DEPTH)+1
   )
   port map
   (
      sleep         => '0',           -- 1-bit input: Dynamic power saving- If sleep is High, the memory/fifo block is in power saving mode.
      
      rst           => reset,         -- 1-bit input: must be synchronous to wr_clk. The clocks can be unstable at the time of applying reset, but release reset only after the clocks is/are stable.
      
      wr_clk        => clock,         -- 1-bit input: Write clock: Used for write operation. wr_clk must be a free running clock.
      wr_rst_busy   => open,          -- 1-bit output: Write Reset Busy: Active-High indicator that the FIFO write domain remains in a reset state.
    

      wr_en         => wr_en,         -- 1-bit input: Write Enable: If the FIFO is not full, asserting this signal writes data (on din) to the FIFO
                                      -- Hold this signal active-Low when rst or wr_rst_busy or rd_rst_busy is active-High

      din           => din,           -- WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when writing the FIFO.
      wr_ack        => open,          -- 1-bit output: Write Acknowledge: This signal indicates that a write request (wr_en) during the prior clock cycle succeeded.

      full          => open,          -- 1-bit output: Full Flag: When asserted, this signal indicates that the FIFO is full. The FIFO ignores write
                                      -- requests when the FIFO is full, initiating a write when the FIFO is full is not destructive to the contents
                                      -- of the FIFO.

      almost_full   => open,          -- 1-bit output: Almost Full: When asserted, this signal indicates that the FIFO can perform only one more
                                      -- write before it is full.

      prog_full     => open,          -- 1-bit output: Programmable Full: This signal asserts when the number of words in the FIFO is greater than or
                                      -- equal to the programmable full threshold value. It de-asserts when the number of words in the FIFO is less
                                      -- than the programmable full threshold value.

      overflow      => open,          -- 1-bit output: Overflow: This signal indicates that a write request (wren) during the prior clock cycle was
                                      -- rejected, because the FIFO is full. Overflowing the FIFO is not destructive to the contents of the FIFO.

      wr_data_count => wr_data_count, -- WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates the number of words written into the
                                      -- FIFO.

      rd_rst_busy   => rd_rst_busy,   -- 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read domain remains in a reset state.
      rd_en         => rd_en,         -- 1-bit input: Read Enable: If the FIFO is not empty, asserting this signal reads data (on dout) from the
                                      -- FIFO. Hold this signal active-Low when rd_rst_busy is active-High.

      dout          => dout,          -- READ_DATA_WIDTH-bit output: Read Data: This drives the output data bus when reading the FIFO.
      data_valid    => data_valid,    -- 1-bit output: Read Data Valid: When asserted, this signal indicates that valid data appears on the output
                                      -- bus (dout).

      empty         => empty,         -- 1-bit output: Empty Flag: When asserted, this signal indicates that the FIFO is empty. The FIFO ignores read
                                      -- requests when the FIFO is empty, initiating a read while empty is not destructive to the FIFO.

      almost_empty  => open,          -- 1-bit output: Almost Empty : When asserted, this signal indicates that the FIFO can provide only one more
                                      -- read before it goes to empty.

      prog_empty    => open,          -- 1-bit output: Programmable Empty: This signal asserts when the number of words in the FIFO is less than or
                                      -- equal to the programmable empty threshold value. It de-asserts when the number of words in the FIFO exceeds
                                      -- the programmable empty threshold value.

      underflow     => open,          -- 1-bit output: Underflow: Indicates that the read request (rd_en) during the previous clock cycle was
                                      -- rejected because the FIFO is empty. Under flowing the FIFO is not destructive to the FIFO.

      rd_data_count => rd_data_count, -- RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the number of words read from the FIFO.
      injectsbiterr => '0',           -- 1-bit input: Single Bit Error Injection: Injects a single bit error if using the ECC feature on block RAMs
                                      -- or UltraRAM macros.

      injectdbiterr => '0',           -- 1-bit input: Double Bit Error Injection: Injects a double bit error if using the ECC feature on block RAMs
                                      -- or UltraRAM macros.

      sbiterr       => open,          -- 1-bit output: Single Bit Error: Indicates that the ECC decoder detected and fixed a single-bit error.
      dbiterr       => open           -- 1-bit output: Double Bit Error: Indicates that the ECC decoder detected a double-bit error and data in the
                                      -- FIFO core becomes corrupted.
   );

   

end archDefault;