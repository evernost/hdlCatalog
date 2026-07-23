-- ============================================================================
-- Project        : -
-- Module name    : axi_mover
-- File name      : axi_mover.vhd
-- File type      : VHDL 2008
-- Purpose        : tiny AXI data mover 
-- Author         : QuBi (nitrogenium@outlook.fr)
-- Creation date  : Thursday, 16 July 2026
-- ----------------------------------------------------------------------------
-- Best viewed with space indentation (2 spaces)
-- ============================================================================

-- ============================================================================
-- DESCRIPTION
-- ============================================================================
-- AXI MOVER
--
-- AXI3 read master (Zynq-7000 PS HP-port compatible) that fetches G_NUM_WORDS
-- 64-bit words starting at a run-time address, and streams them out on a
-- simplified AXI4-Stream interface.
--
-- Design assumptions:
--   * Downstream AXI-Stream sink is ALWAYS ready -> m_axis_tready is not
--     used to gate anything, it is only sampled/ignored. RREADY is tied
--     permanently high, so there is zero back-pressure anywhere in the path.
--   * No outstanding bursts: one AXI burst is issued, fully drained, and
--     only then is the next AR issued.
--   * G_NUM_WORDS is a compile-time generic, max 2048 (fits a Zynq-style
--     HP-port use case comfortably, see notes below).
--
-- AXI3 vs AXI4 notes:
--   * ARLEN is 4 bits on AXI3 -> max burst = 16 beats. At 8 bytes/beat that
--     is 128 bytes/burst, so 2048 words = up to 128 bursts.
--   * ARLOCK is 2 bits on AXI3 (vs 1 bit on AXI4).
--   * No WID/AWID needed: this is a read-only master.
--
-- 4KB boundary handling:
--   AXI forbids a single burst from crossing a 4KB address boundary. Rather
--   than requiring the caller to guarantee alignment, each burst length is
--   computed on the fly as:
--       burst_len = min(16, words_left, beats_remaining_to_next_4K_boundary)
--   This makes the block safe for ANY start address (as long as it is
--   8-byte aligned, i.e. addr(2:0) = "000", which is required anyway since
--   each beat transfers one 64-bit word).
--
-- Throughput note:
--   Because bursts are not pipelined (no outstanding AR while draining R),
--   there is a small bubble (AR issue + slave latency) between bursts. For
--   16-beat bursts this overhead is usually a small fraction of the burst
--   time on Zynq HP ports. If you later need to hide it, the natural
--   extension is to issue the next AR as soon as the current one is
--   accepted, before RLAST of the previous burst -- left out here since a
--   single-outstanding design was explicitly requested.



-- ============================================================================
-- LIBRARIES
-- ============================================================================
-- Standard libraries
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

-- Project libraries
-- library axi_mover_lib; use axi_mover_lib.axi_mover_pkg.all;
-- None.



-- ============================================================================
-- I/O DESCRIPTION
-- ============================================================================
entity axi_mover is
generic
(
  RESET_POL         : STD_LOGIC;
  RESET_SYNC        : BOOLEAN;
  M_AXI_ADDR_WIDTH  : INTEGER;
  M_AXI_DATA_WIDTH  : INTEGER;
  M_AXI_ID_WIDTH    : INTEGER;
  TRANSFER_LEN      : INTEGER
);
port
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
end entity axi_mover;



architecture archDefault of axi_mover is

  constant C_MAX_BURST_BEATS  : INTEGER := 16; -- AXI3 hard limit (ARLEN is 4 bits)
  constant ARCACHE_VALUE      : STD_LOGIC_VECTOR(3 downto 0) := "0011";

  type t_state is (S_IDLE, S_CALC_BURST, S_AR, S_RDATA, S_DONE);
  signal state       : t_state := S_IDLE;

  signal cur_addr     : unsigned(M_AXI_ADDR_WIDTH-1 downto 0);
  signal words_left   : INTEGER range 0 to TRANSFER_LEN;
  signal burst_len    : INTEGER range 1 to C_MAX_BURST_BEATS;

  signal axi_arvalid  : STD_LOGIC;

begin

  -- --------------------------------------------------------------------------
  -- Static / quasi-static AXI signalling
  -- --------------------------------------------------------------------------
  m_axi_arid    <= (others => '0');            -- single outstanding burst -> ID irrelevant
  m_axi_arsize  <= "011";                      -- 2^3 = 8 bytes per beat (64-bit word)
  m_axi_arburst <= "01";                       -- INCR
  m_axi_arlock  <= "00";                       -- normal access
  m_axi_arcache <= ARCACHE_VALUE;
  m_axi_arprot  <= "000";
  m_axi_arqos   <= "0000";

  m_axi_araddr  <= std_logic_vector(cur_addr);
  m_axi_arlen   <= std_logic_vector(to_unsigned(burst_len - 1, 4));

  m_axi_rready  <= '1';

  m_axi_arvalid <= axi_arvalid;

  -- --------------------------------------------------------------------------
  -- AXI4-Stream passthrough (combinational, zero extra latency)
  -- --------------------------------------------------------------------------
  m_axis_tdata  <= m_axi_rdata;
  m_axis_tvalid <= '1' when (state = S_RDATA and m_axi_rvalid = '1') else '0';
  m_axis_tlast  <= '1' when (state = S_RDATA and m_axi_rvalid = '1' and words_left = 1) else '0';



  -- --------------------------------------------------------------------------
  -- Main FSM
  -- --------------------------------------------------------------------------
  p_fsm : process(clock, reset)
  procedure resetProcedure is 
  begin
    state       <= S_IDLE;
    cur_addr    <= (others => '0');
    words_left  <= 0;
    burst_len   <= 1;
    axi_arvalid <= '0';
    busy        <= '0';
    done        <= '0';
    rresp_error <= '0';
  end resetProcedure;
  
    variable v_offset_in_4k : integer range 0 to 4095;
    variable v_beats_to_4k  : integer range 1 to 512;
    variable v_burst_len    : integer range 1 to C_MAX_BURST_BEATS;
    
  begin
  
    if (not(RESET_SYNC) and (reset = RESET_POL)) then
      resetProcedure;
    elsif (clock'event and (clock = '1')) then
      if (RESET_SYNC and (reset = RESET_POL)) then
        resetProcedure;
      else
        -- default single-cycle pulses
        done <= '0';

        case state is

          when S_IDLE =>
            if trigger = '1' then
              cur_addr      <= unsigned(start_addr);
              words_left    <= TRANSFER_LEN;
              busy        <= '1';
              rresp_error <= '0';
              state         <= S_CALC_BURST;
            end if;

          when S_CALC_BURST =>
            -- compute burst length so we never cross a 4KB boundary
            v_offset_in_4k := to_integer(cur_addr(11 downto 0));
            v_beats_to_4k  := (4096 - v_offset_in_4k) / 8;

            v_burst_len := C_MAX_BURST_BEATS;
            if words_left < v_burst_len then
              v_burst_len := words_left;
            end if;
            if v_beats_to_4k < v_burst_len then
              v_burst_len := v_beats_to_4k;
            end if;

            burst_len     <= v_burst_len;
            axi_arvalid   <= '1';
            state         <= S_AR;

          when S_AR =>
            if axi_arvalid = '1' and m_axi_arready = '1' then
              axi_arvalid <= '0';
              state         <= S_RDATA;
            end if;

          when S_RDATA =>
            if m_axi_rvalid = '1' then
              if m_axi_rresp /= "00" then
                rresp_error <= '1';
              end if;

              cur_addr   <= cur_addr + 8;
              words_left <= words_left - 1;

              if words_left = 1 then
                -- last word of the ENTIRE transfer
                state <= S_DONE;
              elsif m_axi_rlast = '1' then
                -- end of this AXI burst, more words remain -> issue next AR
                state <= S_CALC_BURST;
              end if;
            end if;

          when S_DONE =>
            busy <= '0';
            done <= '1';
            state  <= S_IDLE;

        end case;
      end if;
    end if;
  end process p_fsm;

end architecture archDefault;