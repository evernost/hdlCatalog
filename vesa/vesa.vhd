-- ============================================================================
-- Project        : hdlCatalog/vesa
-- Module name    : vesa
-- File name      : vesa.vhd
-- File type      : VHDL 2008
-- Purpose        : VESA controller top level
-- Author         : QuBi (nitrogenium@outlook.fr)
-- Creation date  : Monday, 25 August 2025
-- ----------------------------------------------------------------------------
-- Best viewed with space indentation (2 spaces)
-- ============================================================================

-- ============================================================================
-- DESCRIPTION
-- ============================================================================
-- Full description is TODO. Be patient.



-- ============================================================================
-- LIBRARIES
-- ============================================================================
-- Standard libraries
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Project libraries
library vesa_lib; use vesa_lib.vesa_pkg.all;



-- ============================================================================
-- I/O DESCRIPTION
-- ============================================================================
entity vesa is
generic
(
  RESET_SYNC      : BOOLEAN;
  RESET_POL       : STD_LOGIC;
  PIXEL_DATA_BUS  : INTEGER;
  H_ACTIVE_POL    : STD_LOGIC;
  V_ACTIVE_POL    : STD_LOGIC;
  H_SYNC_TIME     : NATURAL range 1 to 8191;    -- H_SYNC burst duration (expressed in clock ticks)
  H_BACK_PORCH    : NATURAL range 1 to 8191;
  H_LEFT_BORDER   : NATURAL range 0 to 8191;
  H_ADDR_TIME     : NATURAL range 1 to 8191;
  H_RIGHT_BORDER  : NATURAL range 0 to 8191;
  H_FRONT_PORCH   : NATURAL range 1 to 8191;
  V_SYNC_TIME     : NATURAL range 1 to 8191;    -- V_SYNC burst duration (expressed in line time)
  V_BACK_PORCH    : NATURAL range 1 to 8191;
  V_TOP_BORDER    : NATURAL range 0 to 8191;
  V_ADDR_TIME     : NATURAL range 1 to 8191;
  V_BOTTOM_BORDER : NATURAL range 0 to 8191;
  V_FRONT_PORCH   : NATURAL range 1 to 8191;
  HV_DELAY        : INTEGER range -128 to 127   -- V_SYNC lag with respect to the H_SYNC (expressed in clock ticks). "HV_DELAY > 0" means V_SYNC will come AFTER H_SYNC.
);
port
( 
  clock         : in STD_LOGIC;
  reset         : in STD_LOGIC; 
  
  -- VIDEO INPUT: AXI3 master read address channel
  m_axi_arid    : out STD_LOGIC_VECTOR(M_AXI_ID_WIDTH-1 downto 0);
  m_axi_araddr  : out STD_LOGIC_VECTOR(M_AXI_ADDR_WIDTH-1 downto 0);
  m_axi_arlen   : out STD_LOGIC_VECTOR(3 downto 0);   -- AXI3: 4 bits
  m_axi_arsize  : out STD_LOGIC_VECTOR(2 downto 0);
  m_axi_arburst : out STD_LOGIC_VECTOR(1 downto 0);
  m_axi_arlock  : out STD_LOGIC_VECTOR(1 downto 0);   -- AXI3: 2 bits
  m_axi_arcache : out STD_LOGIC_VECTOR(3 downto 0);
  m_axi_arprot  : out STD_LOGIC_VECTOR(2 downto 0);
  m_axi_arqos   : out STD_LOGIC_VECTOR(3 downto 0);
  m_axi_arvalid : out STD_LOGIC;
  m_axi_arready : in  STD_LOGIC;

  -- VIDEO INPUT: AXI3 master read data channel
  m_axi_rid     : in  STD_LOGIC_VECTOR(M_AXI_ID_WIDTH-1 downto 0);
  m_axi_rdata   : in  STD_LOGIC_VECTOR(63 downto 0);
  m_axi_rresp   : in  STD_LOGIC_VECTOR(1 downto 0);
  m_axi_rlast   : in  STD_LOGIC;
  m_axi_rvalid  : in  STD_LOGIC;
  m_axi_rready  : out STD_LOGIC;
  
  -- VGA output signals
  vga_hsync   : out STD_LOGIC;
  vga_vsync   : out STD_LOGIC;
  vga_red     : out STD_LOGIC_VECTOR(3 downto 0);
  vga_green   : out STD_LOGIC_VECTOR(3 downto 0);
  vga_blue    : out STD_LOGIC_VECTOR(3 downto 0)
);
end vesa;



-- ============================================================================
-- ARCHITECTURE
-- ============================================================================
architecture archDefault of vesa is


begin

  -- --------------------------------------------------------------------------
  -- CORE
  -- --------------------------------------------------------------------------
  vesa_core_0 : entity vesa_lib.vesa_core(archDefault)
  generic map
  (
    RESET_POL       => RESET_POL,
    RESET_SYNC      => RESET_SYNC,
    PIXEL_DATA_BUS  => PIXEL_DATA_BUS,
    H_ACTIVE_POL    => H_ACTIVE_POL,
    V_ACTIVE_POL    => V_ACTIVE_POL,
    H_SYNC_TIME     => H_SYNC_TIME,
    H_BACK_PORCH    => H_BACK_PORCH,
    H_LEFT_BORDER   => H_LEFT_BORDER,
    H_ADDR_TIME     => H_ADDR_TIME,
    H_RIGHT_BORDER  => H_RIGHT_BORDER,
    H_FRONT_PORCH   => H_FRONT_PORCH,
    V_SYNC_TIME     => V_SYNC_TIME,
    V_BACK_PORCH    => V_BACK_PORCH,
    V_TOP_BORDER    => V_TOP_BORDER,
    V_ADDR_TIME     => V_ADDR_TIME,
    V_BOTTOM_BORDER => V_BOTTOM_BORDER,
    V_FRONT_PORCH   => V_FRONT_PORCH,
    HV_DELAY        => HV_DELAY
  )
  port map
  ( 
    clock           => clock,
    reset           => reset,
    
    
  );



  -- --------------------------------------------------------------------------
  -- AXI DATA MOVER (TINY)
  -- --------------------------------------------------------------------------
  vesa_axi_mover_0 : entity vesa_lib.vesa_axi_mover(archDefault)
  generic map
  (
    RESET_POL         => RESET_POL,
    RESET_SYNC        => RESET_SYNC,
    M_AXI_ADDR_WIDTH  => 32,
    M_AXI_DATA_WIDTH  => 64,
    M_AXI_ID_WIDTH    => 6,
    TRANSFER_LEN      => H_ADDR_TIME
  )
  port map
  (
    clock         : in  STD_LOGIC;
    reset         : in  STD_LOGIC;

    -- Control
    trigger       : in  STD_LOGIC;
    start_addr    : in  STD_LOGIC_VECTOR(M_AXI_ADDR_WIDTH-1 downto 0);
    busy          => 
    done          => 
    rresp_error   => 

    -- AXI3 master read address channel
    m_axi_arid    => 
    m_axi_araddr  => 
    m_axi_arlen   => 
    m_axi_arsize  => 
    m_axi_arburst => 
    m_axi_arlock  => 
    m_axi_arcache => 
    m_axi_arprot  => 
    m_axi_arqos   =>
    m_axi_arvalid => 
    m_axi_arready =>

    -- AXI3 master read data channel
    m_axi_rid      : in  std_logic_vector(M_AXI_ID_WIDTH-1 downto 0);
    m_axi_rdata    : in  std_logic_vector(M_AXI_DATA_WIDTH-1 downto 0);
    m_axi_rresp    : in  std_logic_vector(1 downto 0);
    m_axi_rlast    : in  STD_LOGIC;
    m_axi_rvalid   : in  STD_LOGIC;
    m_axi_rready   : out STD_LOGIC;

    -- Simplified AXI4-Stream master (sink assumed always ready)
    m_axis_tdata   : out std_logic_vector(M_AXI_DATA_WIDTH-1 downto 0);
    m_axis_tvalid  : out STD_LOGIC;
    m_axis_tlast   : out STD_LOGIC
  );
  



  vesa_lineFifo_odd : entity vesa_lib.vesa_line_fifo(archDefault)
  generic map
  (
    RESET_POL   => RESET_POL,
    RESET_SYNC  => RESET_SYNC
  );
  port map
  ( 
    clock           => clock,
    reset           => reset,

    
  );
  
  vesa_lineFifo_even : entity vesa_lib.vesa_line_fifo(archDefault)
  generic map
  (
    RESET_POL   => RESET_POL,
    RESET_SYNC  => RESET_SYNC
  );
  port map
  ( 
    clock           => clock,
    reset           => reset,

    
  );




  -- --------------------------------------------------------------------------
  -- PALETTE
  -- --------------------------------------------------------------------------
  vesa_palette : entity vesa_lib.vesa_palette(archDefault)
  generic map
  (
    RESET_POL       => RESET_POL,
    RESET_SYNC      => RESET_SYNC,
    PIXEL_DATA_BUS  => 32
  )
  port map
  ( 
    clock           : in STD_LOGIC;
    reset           : in STD_LOGIC; 
    
    -- VIDEO IN
    display_in_hsync  => 
    display_in_vsync  => 
    display_in_data   => 
    
    -- VIDEO OUT
    display_out_hsync => vga_hsync,
    display_out_vsync => vga_vsync,
    display_out_red   => vga_red,
    display_out_green => vga_green,
    display_out_blue  => vga_red,
    vga_green     : out STD_LOGIC_VECTOR(3 downto 0);
    vga_blue      : out STD_LOGIC_VECTOR(3 downto 0)
  );




end archDefault;

