-- ============================================================================
-- Project        : -
-- Module name    : testbench
-- File name      : testbench.vhd
-- File type      : VHDL 2008
-- Purpose        : testbench for the AXI data mover
-- Author         : QuBi (nitrogenium@outlook.fr)
-- Creation date  : Tuesday, 21 July 2026
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
-- library debouncer_lib; use debouncer_lib.debouncer_pkg.all;



-- ============================================================================
-- I/O DESCRIPTION
-- ============================================================================
entity testbench is
generic
(
  RESET_POL   : STD_LOGIC := '0';
  RESET_SYNC  : BOOLEAN := TRUE;
);
end testbench;



-- ============================================================================
-- ARCHITECTURE
-- ============================================================================
architecture archDefault of testbench is

  constant clock_period : TIME := 1 sec / (CLOCK_FREQ_MHZ * 1.0E6);
  
  signal clock  : STD_LOGIC := '0';
  signal reset  : STD_LOGIC := '0';

  

begin

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
  
  -- --------------------------------------------------------------------------
  -- DUT
  -- --------------------------------------------------------------------------
  dut_axi_mover_0 : entity axi_mover_lib.axi_mover(archDefault)
  generic map
  (
    RESET_POL         => 
    RESET_SYNC        => 
    M_AXI_ADDR_WIDTH  => 
    M_AXI_DATA_WIDTH  => 
    M_AXI_ID_WIDTH    => 
    TRANSFER_LEN      => 
  )
  port map
  (
    -- System
    clock         : in  STD_LOGIC;
    reset         : in  STD_LOGIC;

    -- Control
    trigger       : in  STD_LOGIC;
    start_addr    : in  STD_LOGIC_VECTOR(M_AXI_ADDR_WIDTH-1 downto 0);
    busy          : out STD_LOGIC;
    done          : out STD_LOGIC;
    rresp_error   : out STD_LOGIC;

    -- AXI3 master read address channel
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

    -- AXI3 master read data channel
    m_axi_rid     : in  STD_LOGIC_VECTOR(M_AXI_ID_WIDTH-1 downto 0);
    m_axi_rdata   : in  STD_LOGIC_VECTOR(M_AXI_DATA_WIDTH-1 downto 0);
    m_axi_rresp   : in  STD_LOGIC_VECTOR(1 downto 0);
    m_axi_rlast   : in  STD_LOGIC;
    m_axi_rvalid  : in  STD_LOGIC;
    m_axi_rready  : out STD_LOGIC;

    -- Simplified AXI4-Stream master (sink assumed always ready)
    m_axis_tdata  : out STD_LOGIC_VECTOR(M_AXI_DATA_WIDTH-1 downto 0);
    m_axis_tvalid : out STD_LOGIC;
    m_axis_tlast  : out STD_LOGIC
  );
  
  
  -- --------------------------------------------------------------------------
  -- DUT
  -- --------------------------------------------------------------------------
  dut_debouncer_0 : entity axi_mover_lib.axi_mover(archDefault)
  generic
  (
    G_DATA_WIDTH : integer := 64;   -- bus data width in bits
    G_ADDR_WIDTH : integer := 32;
    G_ID_WIDTH   : integer := 4;

    -- Emulated memory window
    G_MEM_WORDS     : integer := 2048;                    -- depth, in G_DATA_WIDTH-bit words
    G_MEM_BASE_ADDR : std_logic_vector(31 downto 0) := x"00000000";

    -- Slave-side handshake latency, in clock cycles (min=max=0 -> zero wait states)
    G_ARREADY_DELAY_MIN : integer := 0;
    G_ARREADY_DELAY_MAX : integer := 0;
    G_RVALID_DELAY_MIN  : integer := 0;   -- applied before EACH R beat
    G_RVALID_DELAY_MAX  : integer := 0;
    G_AWREADY_DELAY_MIN : integer := 0;
    G_AWREADY_DELAY_MAX : integer := 0;
    G_WREADY_DELAY_MIN  : integer := 0;   -- applied before EACH W beat
    G_WREADY_DELAY_MAX  : integer := 0;
    G_BVALID_DELAY_MIN  : integer := 0;
    G_BVALID_DELAY_MAX  : integer := 0;

    G_STRICT_CHECKS : boolean := false;  -- true => protocol violations are ERROR (kills sim)
    G_VERBOSE       : boolean := true    -- true => print each transaction
  );
  port (
    S_AXI_ACLK    : in  std_logic;
    S_AXI_ARESETN : in  std_logic;

    -- Write address channel
    S_AXI_AWID    : in  std_logic_vector(G_ID_WIDTH-1 downto 0);
    S_AXI_AWADDR  : in  std_logic_vector(G_ADDR_WIDTH-1 downto 0);
    S_AXI_AWLEN   : in  std_logic_vector(3 downto 0);
    S_AXI_AWSIZE  : in  std_logic_vector(2 downto 0);
    S_AXI_AWBURST : in  std_logic_vector(1 downto 0);
    S_AXI_AWLOCK  : in  std_logic_vector(1 downto 0);
    S_AXI_AWCACHE : in  std_logic_vector(3 downto 0);
    S_AXI_AWPROT  : in  std_logic_vector(2 downto 0);
    S_AXI_AWVALID : in  std_logic;
    S_AXI_AWREADY : out std_logic;

    -- Write data channel (AXI3 has WID; AXI4 does not)
    S_AXI_WID     : in  std_logic_vector(G_ID_WIDTH-1 downto 0);
    S_AXI_WDATA   : in  std_logic_vector(G_DATA_WIDTH-1 downto 0);
    S_AXI_WSTRB   : in  std_logic_vector(G_DATA_WIDTH/8-1 downto 0);
    S_AXI_WLAST   : in  std_logic;
    S_AXI_WVALID  : in  std_logic;
    S_AXI_WREADY  : out std_logic;

    -- Write response channel
    S_AXI_BID     : out std_logic_vector(G_ID_WIDTH-1 downto 0);
    S_AXI_BRESP   : out std_logic_vector(1 downto 0);
    S_AXI_BVALID  : out std_logic;
    S_AXI_BREADY  : in  std_logic;

    -- Read address channel
    S_AXI_ARID    : in  std_logic_vector(G_ID_WIDTH-1 downto 0);
    S_AXI_ARADDR  : in  std_logic_vector(G_ADDR_WIDTH-1 downto 0);
    S_AXI_ARLEN   : in  std_logic_vector(3 downto 0);
    S_AXI_ARSIZE  : in  std_logic_vector(2 downto 0);
    S_AXI_ARBURST : in  std_logic_vector(1 downto 0);
    S_AXI_ARLOCK  : in  std_logic_vector(1 downto 0);
    S_AXI_ARCACHE : in  std_logic_vector(3 downto 0);
    S_AXI_ARPROT  : in  std_logic_vector(2 downto 0);
    S_AXI_ARVALID : in  std_logic;
    S_AXI_ARREADY : out std_logic;

    -- Read data channel
    S_AXI_RID     : out std_logic_vector(G_ID_WIDTH-1 downto 0);
    S_AXI_RDATA   : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
    S_AXI_RRESP   : out std_logic_vector(1 downto 0);
    S_AXI_RLAST   : out std_logic;
    S_AXI_RVALID  : out std_logic;
    S_AXI_RREADY  : in  std_logic
  );

  
  
end archDefault;
