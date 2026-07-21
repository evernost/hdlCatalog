--------------------------------------------------------------------------------
-- axi3_ddr_slave.vhd
--
-- SIMULATION-ONLY AXI3 slave. Emulates the Zynq PS "DDR behind the HP port"
-- for testing an AXI3 read master (e.g. a burst DMA fetching 1024 x 64-bit
-- words). Do NOT synthesize this file (uses ieee.math_real + initialisation
-- functions) -- in Vivado, add it to the "Simulation Sources" fileset only
-- (Source File Properties -> untick "Used in: Synthesis").
--
-- Features
--   * Internal memory (G_MEM_WORDS x G_DATA_WIDTH-bit, default 2048 x 64b)
--     pre-loaded with a counter pattern: mem(i) = i. Makes it trivial to
--     check from the master side that beat N of a burst really came from
--     address base + N*8.
--   * Full AXI3 read channel (AR/R): FIXED / INCR / WRAP bursts, ARLEN up to
--     16 beats (AXI3's 4-bit AxLEN), independently configurable ARREADY and
--     RVALID latency (fixed or randomised range) to shake out timing
--     assumptions in the master. Defaults to zero wait states.
--   * Minimal-but-correct AXI3 write channel (AW/W/B) including the AXI3-only
--     WID check (write data must carry the ID of the AW it belongs to), so
--     the model won't misbehave if a write ever appears on the bus.
--   * Protocol checker (WARNING by default, promote to ERROR via
--     G_STRICT_CHECKS) covering:
--       - X/U on control signals while VALID=1
--       - VALID deasserted before the matching READY (must hold until the
--         handshake completes)
--       - burst crossing a 4KB boundary
--       - AxSIZE wider than the data bus
--       - WRAP burst length not in {1,2,4,8,16}, or unaligned WRAP address
--       - WID /= AWID during a write burst (AXI3 requirement)
--       - WLAST asserted on the wrong beat
--       - address outside the emulated memory window
--       - reserved AxBURST = "11"
--
-- Only one outstanding transaction per channel is supported (matches a
-- simple, non-pipelined master with no need for outstanding bursts).
--
-- Example instantiation (2048 words = 16KB emulated DDR window, zero wait
-- states, warnings only):
--
--   u_ddr_model : entity work.axi3_ddr_slave
--     generic map (
--       G_DATA_WIDTH => 64,
--       G_ADDR_WIDTH => 32,
--       G_ID_WIDTH   => 4,
--       G_MEM_WORDS  => 2048
--     )
--     port map (
--       S_AXI_ACLK    => aclk,
--       S_AXI_ARESETN => aresetn,
--       S_AXI_AWID    => m_axi_awid,     -- connect every S_AXI_* to the
--       S_AXI_AWADDR  => m_axi_awaddr,   -- matching M_AXI_* on your master
--       ...
--     );
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity axi3_ddr_slave is
  generic (
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
end entity axi3_ddr_slave;

architecture sim of axi3_ddr_slave is

  -----------------------------------------------------------------------------
  -- Memory, pre-loaded with a counter pattern: mem(i) = i
  -----------------------------------------------------------------------------
  type mem_array_t is array (natural range <>) of std_logic_vector(G_DATA_WIDTH-1 downto 0);

  impure function init_mem(depth : integer) return mem_array_t is
    variable m : mem_array_t(0 to depth-1);
  begin
    for i in 0 to depth-1 loop
      m(i) := std_logic_vector(to_unsigned(i, G_DATA_WIDTH));
    end loop;
    return m;
  end function;

  signal mem : mem_array_t(0 to G_MEM_WORDS-1) := init_mem(G_MEM_WORDS);

  constant BYTES_PER_WORD : integer := G_DATA_WIDTH/8;
  constant STROBE_BITS    : integer := G_DATA_WIDTH/8;

  -----------------------------------------------------------------------------
  -- Small helpers
  -----------------------------------------------------------------------------
  function is_x(s : std_logic) return boolean is
  begin
    return (s = 'X') or (s = 'U') or (s = '-') or (s = 'Z') or (s = 'W');
  end function;

  function has_x(v : std_logic_vector) return boolean is
  begin
    for i in v'range loop
      if is_x(v(i)) then
        return true;
      end if;
    end loop;
    return false;
  end function;

  procedure report_violation(msg : in string) is
  begin
    if G_STRICT_CHECKS then
      report "AXI3_DDR_SLAVE protocol violation: " & msg severity error;
    else
      report "AXI3_DDR_SLAVE protocol violation: " & msg severity warning;
    end if;
  end procedure;

  -- Next address for one more beat of a burst (AXI address-generation rules)
  function axi_next_addr(
    addr       : unsigned;
    burst_type : std_logic_vector(1 downto 0);
    size_bytes : integer;
    len_beats  : integer
  ) return unsigned is
    variable wrap_lo, wrap_hi : unsigned(addr'range);
    variable result           : unsigned(addr'range);
  begin
    case burst_type is
      when "00" =>  -- FIXED
        result := addr;
      when "01" =>  -- INCR
        result := addr + to_unsigned(size_bytes, addr'length);
      when "10" =>  -- WRAP
        wrap_lo := (addr / to_unsigned(size_bytes*len_beats, addr'length))
                     * to_unsigned(size_bytes*len_beats, addr'length);
        wrap_hi := wrap_lo + to_unsigned(size_bytes*len_beats, addr'length);
        result  := addr + to_unsigned(size_bytes, addr'length);
        if result = wrap_hi then
          result := wrap_lo;
        end if;
      when others =>  -- reserved, treat as FIXED (violation already reported elsewhere)
        result := addr;
    end case;
    return result;
  end function;

  procedure rand_delay(
    variable seed1, seed2 : inout integer;
    min_val, max_val      : in integer;
    result                : out integer
  ) is
    variable r   : real;
    variable res : integer;
  begin
    if max_val <= min_val then
      res := min_val;
    else
      uniform(seed1, seed2, r);
      res := min_val + integer(r * real(max_val - min_val + 1));
      if res > max_val then
        res := max_val;
      elsif res < min_val then
        res := min_val;
      end if;
    end if;
    result := res;
  end procedure;

  -----------------------------------------------------------------------------
  -- Read-channel state
  -----------------------------------------------------------------------------
  type r_state_t is (R_IDLE, R_AR_WAIT, R_AR_ACK, R_R_WAIT, R_R_ACK);
  signal r_state : r_state_t := R_IDLE;

  signal ar_id_q     : std_logic_vector(G_ID_WIDTH-1 downto 0);
  signal ar_addr_q   : unsigned(G_ADDR_WIDTH-1 downto 0);
  signal ar_size_q   : integer range 0 to 7;
  signal ar_burst_q  : std_logic_vector(1 downto 0);
  signal ar_len_q    : integer range 0 to 15;   -- beats-1
  signal r_beat_cnt  : integer range 0 to 15;
  signal ar_wait_cnt : integer := 0;
  signal r_wait_cnt  : integer := 0;

  signal S_AXI_ARREADY_i : std_logic := '0';
  signal S_AXI_RVALID_i  : std_logic := '0';
  signal S_AXI_RLAST_i   : std_logic := '0';
  signal S_AXI_RDATA_i   : std_logic_vector(G_DATA_WIDTH-1 downto 0) := (others => '0');
  signal S_AXI_RID_i     : std_logic_vector(G_ID_WIDTH-1 downto 0)   := (others => '0');

  -----------------------------------------------------------------------------
  -- Write-channel state
  -----------------------------------------------------------------------------
  type w_state_t is (W_IDLE, W_AW_WAIT, W_AW_ACK, W_W_WAIT, W_W_ACK, W_B_WAIT, W_B_ACK);
  signal w_state : w_state_t := W_IDLE;

  signal aw_id_q     : std_logic_vector(G_ID_WIDTH-1 downto 0);
  signal aw_addr_q   : unsigned(G_ADDR_WIDTH-1 downto 0);
  signal aw_size_q   : integer range 0 to 7;
  signal aw_burst_q  : std_logic_vector(1 downto 0);
  signal aw_len_q    : integer range 0 to 15;   -- beats-1
  signal w_beat_cnt  : integer range 0 to 15;
  signal aw_wait_cnt : integer := 0;
  signal w_wait_cnt  : integer := 0;
  signal b_wait_cnt  : integer := 0;

  signal S_AXI_AWREADY_i : std_logic := '0';
  signal S_AXI_WREADY_i  : std_logic := '0';
  signal S_AXI_BVALID_i  : std_logic := '0';
  signal S_AXI_BID_i     : std_logic_vector(G_ID_WIDTH-1 downto 0) := (others => '0');

  -- previous-cycle VALID/READY, for the "held stable until READY" check
  signal ar_prev_valid : std_logic := '0';
  signal ar_prev_ready : std_logic := '0';
  signal aw_prev_valid : std_logic := '0';
  signal aw_prev_ready : std_logic := '0';
  signal w_prev_valid  : std_logic := '0';
  signal w_prev_ready  : std_logic := '0';

begin

  S_AXI_ARREADY <= S_AXI_ARREADY_i;
  S_AXI_RVALID  <= S_AXI_RVALID_i;
  S_AXI_RLAST   <= S_AXI_RLAST_i;
  S_AXI_RDATA   <= S_AXI_RDATA_i;
  S_AXI_RID     <= S_AXI_RID_i;
  S_AXI_RRESP   <= "00";  -- OKAY, always (this model never returns bus errors)

  S_AXI_AWREADY <= S_AXI_AWREADY_i;
  S_AXI_WREADY  <= S_AXI_WREADY_i;
  S_AXI_BVALID  <= S_AXI_BVALID_i;
  S_AXI_BID     <= S_AXI_BID_i;
  S_AXI_BRESP   <= "00";  -- OKAY

  -----------------------------------------------------------------------------
  -- READ channel FSM
  --   R_IDLE    : wait for ARVALID; latch + statically check the burst
  --   R_AR_WAIT : count down ar_wait_cnt, then raise ARREADY
  --   R_AR_ACK  : ARREADY was high through the previous cycle; confirm the
  --               handshake (ARVALID must still be 1) and move to the burst
  --   R_R_WAIT  : count down r_wait_cnt (per beat), then present data+RVALID
  --   R_R_ACK   : RVALID held high until RREADY=1; then advance or finish
  -----------------------------------------------------------------------------
  read_proc : process(S_AXI_ACLK)
    variable seed1, seed2 : integer := 17;
    variable delay        : integer;
    variable size_bytes   : integer;
    variable beats        : integer;
    variable start_addr_u : unsigned(G_ADDR_WIDTH-1 downto 0);
    variable total_bytes  : integer;
    variable idx          : integer;
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        r_state         <= R_IDLE;
        S_AXI_ARREADY_i <= '0';
        S_AXI_RVALID_i  <= '0';
        S_AXI_RLAST_i   <= '0';
        ar_prev_valid   <= '0';
      else

        -- ARVALID must not drop before ARREADY completes the handshake.
        -- Uses the READY value from the cycle ARVALID was last seen high
        -- (not the current cycle's READY, which is correctly low the cycle
        -- right after a completed handshake).
        if (ar_prev_valid = '1') and (ar_prev_ready = '0') and (S_AXI_ARVALID = '0') then
          report_violation("ARVALID deasserted before ARREADY (must hold ARVALID high until the handshake)");
        end if;
        ar_prev_valid <= S_AXI_ARVALID;
        ar_prev_ready <= S_AXI_ARREADY_i;

        if S_AXI_ARVALID = '1' and has_x(S_AXI_ARADDR & S_AXI_ARLEN & S_AXI_ARSIZE & S_AXI_ARBURST) then
          report_violation("ARADDR/ARLEN/ARSIZE/ARBURST contain X/U while ARVALID=1");
        end if;

        case r_state is

          when R_IDLE =>
            S_AXI_RVALID_i <= '0';
            S_AXI_RLAST_i  <= '0';
            if S_AXI_ARVALID = '1' then
              size_bytes   := 2**to_integer(unsigned(S_AXI_ARSIZE));
              beats        := to_integer(unsigned(S_AXI_ARLEN)) + 1;
              start_addr_u := unsigned(S_AXI_ARADDR);

              if size_bytes > BYTES_PER_WORD then
                report_violation("ARSIZE (" & integer'image(size_bytes) &
                                  " bytes/beat) wider than the slave data bus (" &
                                  integer'image(BYTES_PER_WORD) & " bytes)");
              end if;

              total_bytes := beats * size_bytes;
              if (to_integer(start_addr_u) mod 4096) + total_bytes > 4096 then
                report_violation("read burst at 0x" & integer'image(to_integer(start_addr_u)) &
                                  " crosses a 4KB boundary (AXI3 forbids this)");
              end if;

              if S_AXI_ARBURST = "11" then
                report_violation("ARBURST = 11 (reserved value)");
              elsif S_AXI_ARBURST = "10" then  -- WRAP
                if not (beats = 1 or beats = 2 or beats = 4 or beats = 8 or beats = 16) then
                  report_violation("WRAP burst length (" & integer'image(beats) &
                                    " beats) is not 1/2/4/8/16");
                end if;
                if (to_integer(start_addr_u) mod size_bytes) /= 0 then
                  report_violation("WRAP burst ARADDR not aligned to ARSIZE");
                end if;
              end if;

              ar_id_q    <= S_AXI_ARID;
              ar_addr_q  <= start_addr_u;
              ar_size_q  <= to_integer(unsigned(S_AXI_ARSIZE));
              ar_burst_q <= S_AXI_ARBURST;
              ar_len_q   <= to_integer(unsigned(S_AXI_ARLEN));
              r_beat_cnt <= 0;

              rand_delay(seed1, seed2, G_ARREADY_DELAY_MIN, G_ARREADY_DELAY_MAX, delay);
              ar_wait_cnt <= delay;
              r_state     <= R_AR_WAIT;
            end if;

          when R_AR_WAIT =>
            if ar_wait_cnt = 0 then
              S_AXI_ARREADY_i <= '1';
              r_state         <= R_AR_ACK;
            else
              ar_wait_cnt <= ar_wait_cnt - 1;
            end if;

          when R_AR_ACK =>
            S_AXI_ARREADY_i <= '0';
            if S_AXI_ARVALID = '1' then
              rand_delay(seed1, seed2, G_RVALID_DELAY_MIN, G_RVALID_DELAY_MAX, delay);
              r_wait_cnt <= delay;
              r_state    <= R_R_WAIT;
            else
              report_violation("ARVALID dropped while ARREADY was asserted");
              r_state <= R_IDLE;
            end if;

          when R_R_WAIT =>
            if r_wait_cnt = 0 then
              idx := (to_integer(ar_addr_q) - to_integer(unsigned(G_MEM_BASE_ADDR))) / BYTES_PER_WORD;
              if idx < 0 or idx >= G_MEM_WORDS then
                report_violation("read address 0x" & integer'image(to_integer(ar_addr_q)) &
                                  " is outside the emulated memory window (0.." &
                                  integer'image(G_MEM_WORDS-1) & " words)");
                S_AXI_RDATA_i <= (others => 'X');
              else
                S_AXI_RDATA_i <= mem(idx);
              end if;
              S_AXI_RID_i    <= ar_id_q;
              if r_beat_cnt = ar_len_q then
                S_AXI_RLAST_i <= '1';
              else
                S_AXI_RLAST_i <= '0';
              end if;
              S_AXI_RVALID_i <= '1';

              if G_VERBOSE then
                report "AXI3_SLAVE_BFM: R  addr=0x" & integer'image(to_integer(ar_addr_q)) &
                       " idx=" & integer'image(idx) &
                       " beat=" & integer'image(r_beat_cnt) & "/" & integer'image(ar_len_q) &
                       " id=" & integer'image(to_integer(unsigned(ar_id_q)));
              end if;
              r_state <= R_R_ACK;
            else
              r_wait_cnt <= r_wait_cnt - 1;
            end if;

          when R_R_ACK =>
            if S_AXI_RREADY = '1' then
              if S_AXI_RLAST_i = '1' then
                S_AXI_RVALID_i <= '0';
                S_AXI_RLAST_i  <= '0';
                r_state        <= R_IDLE;
              else
                ar_addr_q      <= axi_next_addr(ar_addr_q, ar_burst_q, 2**ar_size_q, ar_len_q+1);
                r_beat_cnt     <= r_beat_cnt + 1;
                S_AXI_RVALID_i <= '0';
                rand_delay(seed1, seed2, G_RVALID_DELAY_MIN, G_RVALID_DELAY_MAX, delay);
                r_wait_cnt     <= delay;
                r_state        <= R_R_WAIT;
              end if;
            end if;
            -- else: hold RVALID/RDATA/RLAST exactly as they are (signals retain value)

        end case;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- WRITE channel FSM (AW + W + B), same wait/ack pattern as the read side.
  -----------------------------------------------------------------------------
  write_proc : process(S_AXI_ACLK)
    variable seed1, seed2 : integer := 91;
    variable delay        : integer;
    variable size_bytes   : integer;
    variable beats        : integer;
    variable start_addr_u : unsigned(G_ADDR_WIDTH-1 downto 0);
    variable total_bytes  : integer;
    variable idx          : integer;
    variable new_word     : std_logic_vector(G_DATA_WIDTH-1 downto 0);
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        w_state         <= W_IDLE;
        S_AXI_AWREADY_i <= '0';
        S_AXI_WREADY_i  <= '0';
        S_AXI_BVALID_i  <= '0';
        aw_prev_valid   <= '0';
        w_prev_valid    <= '0';
      else

        if (aw_prev_valid = '1') and (aw_prev_ready = '0') and (S_AXI_AWVALID = '0') then
          report_violation("AWVALID deasserted before AWREADY");
        end if;
        aw_prev_valid <= S_AXI_AWVALID;
        aw_prev_ready <= S_AXI_AWREADY_i;

        if (w_prev_valid = '1') and (w_prev_ready = '0') and (S_AXI_WVALID = '0') then
          report_violation("WVALID deasserted before WREADY");
        end if;
        w_prev_valid <= S_AXI_WVALID;
        w_prev_ready <= S_AXI_WREADY_i;

        case w_state is

          when W_IDLE =>
            S_AXI_BVALID_i <= '0';
            if S_AXI_AWVALID = '1' then
              size_bytes   := 2**to_integer(unsigned(S_AXI_AWSIZE));
              beats        := to_integer(unsigned(S_AXI_AWLEN)) + 1;
              start_addr_u := unsigned(S_AXI_AWADDR);

              if size_bytes > BYTES_PER_WORD then
                report_violation("AWSIZE wider than the slave data bus");
              end if;
              total_bytes := beats * size_bytes;
              if (to_integer(start_addr_u) mod 4096) + total_bytes > 4096 then
                report_violation("write burst crosses a 4KB boundary");
              end if;
              if S_AXI_AWBURST = "11" then
                report_violation("AWBURST = 11 (reserved value)");
              end if;

              aw_id_q    <= S_AXI_AWID;
              aw_addr_q  <= start_addr_u;
              aw_size_q  <= to_integer(unsigned(S_AXI_AWSIZE));
              aw_burst_q <= S_AXI_AWBURST;
              aw_len_q   <= to_integer(unsigned(S_AXI_AWLEN));
              w_beat_cnt <= 0;

              rand_delay(seed1, seed2, G_AWREADY_DELAY_MIN, G_AWREADY_DELAY_MAX, delay);
              aw_wait_cnt <= delay;
              w_state     <= W_AW_WAIT;
            end if;

          when W_AW_WAIT =>
            if aw_wait_cnt = 0 then
              S_AXI_AWREADY_i <= '1';
              w_state         <= W_AW_ACK;
            else
              aw_wait_cnt <= aw_wait_cnt - 1;
            end if;

          when W_AW_ACK =>
            S_AXI_AWREADY_i <= '0';
            if S_AXI_AWVALID = '1' then
              rand_delay(seed1, seed2, G_WREADY_DELAY_MIN, G_WREADY_DELAY_MAX, delay);
              w_wait_cnt <= delay;
              w_state    <= W_W_WAIT;
            else
              report_violation("AWVALID dropped while AWREADY was asserted");
              w_state <= W_IDLE;
            end if;

          when W_W_WAIT =>
            if w_wait_cnt = 0 then
              S_AXI_WREADY_i <= '1';
              w_state        <= W_W_ACK;
            else
              w_wait_cnt <= w_wait_cnt - 1;
            end if;

          when W_W_ACK =>
            if S_AXI_WVALID = '1' then
              S_AXI_WREADY_i <= '0';

              if S_AXI_WID /= aw_id_q then
                report_violation("WID (0x" & integer'image(to_integer(unsigned(S_AXI_WID))) &
                                  ") does not match AWID (0x" &
                                  integer'image(to_integer(unsigned(aw_id_q))) &
                                  ") -- AXI3 requires write data to carry its AW's ID");
              end if;

              idx := (to_integer(aw_addr_q) - to_integer(unsigned(G_MEM_BASE_ADDR))) / BYTES_PER_WORD;
              if idx < 0 or idx >= G_MEM_WORDS then
                report_violation("write address 0x" & integer'image(to_integer(aw_addr_q)) &
                                  " is outside the emulated memory window");
              else
                new_word := mem(idx);
                for b in 0 to STROBE_BITS-1 loop
                  if S_AXI_WSTRB(b) = '1' then
                    new_word((b+1)*8-1 downto b*8) := S_AXI_WDATA((b+1)*8-1 downto b*8);
                  end if;
                end loop;
                mem(idx) <= new_word;
              end if;

              if G_VERBOSE then
                report "AXI3_SLAVE_BFM: W  addr=0x" & integer'image(to_integer(aw_addr_q)) &
                       " idx=" & integer'image(idx) &
                       " beat=" & integer'image(w_beat_cnt) & "/" & integer'image(aw_len_q);
              end if;

              if (w_beat_cnt = aw_len_q) /= (S_AXI_WLAST = '1') then
                report_violation("WLAST asserted on the wrong beat (expected at beat " &
                                  integer'image(aw_len_q) & ")");
              end if;

              if S_AXI_WLAST = '1' then
                rand_delay(seed1, seed2, G_BVALID_DELAY_MIN, G_BVALID_DELAY_MAX, delay);
                b_wait_cnt  <= delay;
                S_AXI_BID_i <= aw_id_q;
                w_state     <= W_B_WAIT;
              else
                aw_addr_q  <= axi_next_addr(aw_addr_q, aw_burst_q, 2**aw_size_q, aw_len_q+1);
                w_beat_cnt <= w_beat_cnt + 1;
                rand_delay(seed1, seed2, G_WREADY_DELAY_MIN, G_WREADY_DELAY_MAX, delay);
                w_wait_cnt <= delay;
                w_state    <= W_W_WAIT;
              end if;
            end if;
            -- else: hold WREADY as-is (signal retains value)

          when W_B_WAIT =>
            if b_wait_cnt = 0 then
              S_AXI_BVALID_i <= '1';
              w_state        <= W_B_ACK;
            else
              b_wait_cnt <= b_wait_cnt - 1;
            end if;

          when W_B_ACK =>
            if S_AXI_BREADY = '1' then
              S_AXI_BVALID_i <= '0';
              w_state        <= W_IDLE;
            end if;

        end case;
      end if;
    end if;
  end process;

end architecture sim;
