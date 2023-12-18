library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lab_lib;
use lab_lib.util_pkg.all;

 
entity traffic_splitter is
	port (
		clk         : in sl;
		rst         : in sl;

    o_port_a      : out slv(8-1 downto 0);
    o_port_b      : out slv(8-1 downto 0)
	);
end entity;
 
architecture RTL of traffic_splitter is
  constant BYTE_COUNT : natural := etherTraff'length; 
  constant MAC_TO_REPLACE : aslv(0 to 6-1)(8-1 downto 0) := (x"15", x"AD", x"4F", x"33", x"EF", x"1F");
  constant MAC_REPLACING : aslv(0 to 6-1)(8-1 downto 0) := (x"FF", x"EE", x"FF", x"EE", x"FF", x"EE");
  constant MAC_FOR_PB : aslv (0 to 6-1)(8-1 downto 0) := (x"E2", x"AA", x"64", x"03", x"BC", x"12");
  constant PREAMBLE : aslv(0 to 8-1)(8-1 downto 0) := (x"AA", x"AA", x"AA", x"AA", x"AA", x"AA", x"AA", x"AB");

  constant CRC_BIT_COUNT : natural := 32;
  constant CRC_POLYNOME : slv(CRC_BIT_COUNT downto 0) := "100000100110000010001110110110111";

  signal int_en : sl := '0';

  signal data_ptr_reg, data_ptr_next : unsigned(log2c(BYTE_COUNT)-1 downto 0) := (others => '0');
  signal traffic_data : slv(8-1 downto 0);
  signal EOF : boolean := false;

  signal state_reg, state_next : state_t := s_idle;
  signal ll_state_reg, ll_state_next : ll_state_t := s_idle;
  signal ll_fsm_ready : sl := '0';
  signal ll_fsm_start : sl := '0';

  signal ctr_reg, ctr_next : unsigned(2*8-1 downto 0) := (others => '0');

  signal dst_mac_reg, dst_mac_next : aslv(0 to 6-1)(8-1 downto 0) := (others => (others => '0'));
  signal src_mac_reg, src_mac_next : aslv(0 to 6-1)(8-1 downto 0) := (others => (others => '0'));
  signal data_length_reg, data_length_next : aslv(0 to 2-1)(8-1 downto 0) := (others => (others => '0'));
  signal data_mem_reg, data_mem_next : aslv(0 to 1500-1)(8-1 downto 0) := (others => (others => '0'));
  -- using standard Ethernet data length

  signal crc_reg, crc_next : aslv(0 to 4-1)(8-1 downto 0) := (others => (others => '0'));

  signal crc_i_data : slv(8-1 downto 0) := (others => '0');
  signal crc_i_valid : sl := '0';
  signal crc_o_ready : sl := '0';
  signal crc_i_srst : sl := '0';
  signal crc_result : slv(CRC_BIT_COUNT-1 downto 0) := (others => '0');

  signal packet_for_pb_reg, packet_for_pb_next : sl := '0';
  signal replace_src_mac_reg, replace_src_mac_next : sl := '0';

  signal pa_data_output : slv(8-1 downto 0) := (others => '0');
  signal pb_data_output : slv(8-1 downto 0) := (others => '0');
begin
  
  -- reg-state logic
	process(clk, rst) is
	begin
		if rst = '1' then
      state_reg <= s_idle;
      ll_state_reg <= s_idle;
      data_ptr_reg <= (others => '0');
      ctr_reg <= (others => '0');
      dst_mac_reg <= (others => (others => '0'));
      src_mac_reg <= (others => (others => '0'));
      data_length_reg <= (others => (others => '0'));
      data_mem_reg <= (others => (others => '0'));
      crc_reg <= (others => (others => '0'));
      packet_for_pb_reg <= '0';
      replace_src_mac_reg <= '0';
		elsif rising_edge(clk) then
      if int_en = '1' then
        data_ptr_reg <= data_ptr_next;
        ctr_reg <= ctr_next;
        dst_mac_reg <= dst_mac_next;
        src_mac_reg <= src_mac_next;
        data_length_reg <= data_length_next;
        data_mem_reg <= data_mem_next;
        state_reg <= state_next;
        ll_state_reg <= ll_state_next;
        crc_reg <= crc_next;
        packet_for_pb_reg <= packet_for_pb_next;
        replace_src_mac_reg <= replace_src_mac_next;
      end if;
		end if;
	end process;

  int_en <= crc_o_ready;
  
  -- reading from ROM
  traffic_data <= etherTraff(to_integer(data_ptr_reg));

  EOF <= data_ptr_reg = BYTE_COUNT;
  data_ptr_next <= (others => '0') when EOF else
                   data_ptr_reg + 1 when ll_fsm_ready = '1' else
                   data_ptr_reg;

  CRC: entity lab_lib.crc
    generic map (
      BIT_COUNT => CRC_BIT_COUNT
    )
    port map (
      clk => clk,
      rst => rst,

      i_data => crc_i_data,
      i_valid => crc_i_valid,
      o_ready => crc_o_ready,
      i_srst => crc_i_srst,

      i_polynome => CRC_POLYNOME,
      o_crc => crc_result
    );
  -- next-state logic

  process(all) is
  begin
    state_next <= state_reg;
    ll_state_next <= ll_state_reg;
    ctr_next <= ctr_reg;
    dst_mac_next <= dst_mac_reg;
    src_mac_next <= src_mac_reg;
    data_length_next <= data_length_reg;
    data_mem_next <= data_mem_reg;
    crc_next <= crc_reg;
    crc_i_valid <= '0';
    crc_i_data <= (others => '0');
    crc_i_srst <= '0';
    packet_for_pb_next <= packet_for_pb_reg;
    replace_src_mac_next <= replace_src_mac_reg;
    ll_fsm_ready <= '0';
    ll_fsm_start <= '0';
    pa_data_output <= (others => '0');
    pb_data_output <= (others => '0');

    case state_reg is
      when s_idle =>
        if traffic_data = x"AA" then
          state_next <= s_detect_preamble;
        end if;

      when s_detect_preamble =>
        if traffic_data = x"AB" then
          state_next <= s_read_dst_mac;
          ctr_next <= (others => '0');
        end if;

      when s_read_dst_mac =>
        dst_mac_next(to_integer(ctr_reg)) <= traffic_data;
        ctr_next <= ctr_reg + 1;
        if ctr_reg = 6-1 then
          state_next <= s_read_src_mac;
          ctr_next <= (others => '0');
        end if;

        if crc_o_ready = '1' then
          crc_i_data <= traffic_data;
          crc_i_valid <= '1';
        end if;

      when s_read_src_mac =>
        src_mac_next(to_integer(ctr_reg)) <= traffic_data;
        ctr_next <= ctr_reg + 1;
        if ctr_reg = 6-1 then
          state_next <= s_read_len;
          ctr_next <= to_unsigned(2-1, ctr_next'length);
        end if;

        if crc_o_ready = '1' then
          crc_i_data <= traffic_data;
          crc_i_valid <= '1';
        end if;

      when s_read_len =>
        data_length_next(to_integer(ctr_reg)) <= traffic_data;
        ctr_next <= ctr_reg - 1;
        if ctr_reg = 0 then
          state_next <= s_read_data;
          ctr_next(15 downto 8) <= unsigned(data_length_reg(1));
          ctr_next(7 downto 0) <= unsigned(traffic_data);
        end if;

        if crc_o_ready = '1' then
          crc_i_data <= traffic_data;
          crc_i_valid <= '1';
        end if;

      when s_read_data => 
        ctr_next <= ctr_reg - 1;
        data_mem_next(to_integer(ctr_reg-1)) <= traffic_data;
        if ctr_reg = 1 then
          state_next <= s_get_crc;
          ctr_next <= to_unsigned(4, ctr_next'length);
        end if;

        if crc_o_ready = '1' then
          crc_i_data <= traffic_data;
          crc_i_valid <= '1';
        end if;
        
      when s_get_crc =>
        ctr_next <= ctr_reg - 1;
        
        if crc_o_ready = '1' then
          if ctr_reg = 0 then
            crc_next(0) <= crc_result(7 downto 0);
            crc_next(1) <= crc_result(15 downto 8);
            crc_next(2) <= crc_result(23 downto 16);
            crc_next(3) <= crc_result(31 downto 24);
            crc_i_srst <= '1';
            ll_fsm_start <= '1';
            state_next <= s_idle;
          else
            crc_i_data <= x"00";
            crc_i_valid <= '1';
          end if;
        end if;

      
    end case;

    case ll_state_reg is
      when s_idle =>
        ll_fsm_ready <= '1';

        if ll_fsm_start = '1' then
          ll_state_next <= s_send_preamble;
          ctr_next <= to_unsigned(0, ctr_next'length);
        end if;
      when s_send_preamble =>
        ctr_next <= ctr_reg + 1;
        pa_data_output <= PREAMBLE(to_integer(ctr_reg));
        pb_data_output <= PREAMBLE(to_integer(ctr_reg));
        if ctr_reg = 8-1 then
          ll_state_next <= s_send_dst_mac;
          ctr_next <= to_unsigned(0, ctr_next'length);
        end if;
        
      when s_send_dst_mac =>
        ctr_next <= ctr_reg + 1;
        pa_data_output <= dst_mac_reg(to_integer(ctr_reg));
        pb_data_output <= dst_mac_reg(to_integer(ctr_reg));
        if ctr_reg = 6-1 then
          ll_state_next <= s_send_src_mac;
          ctr_next <= to_unsigned(0, ctr_next'length);
        end if;

      when s_send_src_mac =>
        ctr_next <= ctr_reg + 1;

        if replace_src_mac_reg = '1' then
          pa_data_output <= MAC_REPLACING(to_integer(ctr_reg));
        else
          pa_data_output <= src_mac_reg(to_integer(ctr_reg));
        end if;

        pb_data_output <= src_mac_reg(to_integer(ctr_reg));
        if ctr_reg = 6-1 then
          ll_state_next <= s_send_len;
          ctr_next <= to_unsigned(2-1, ctr_next'length);
        end if;

      when s_send_len =>
        ctr_next <= ctr_reg - 1;
        pa_data_output <= data_length_reg(to_integer(ctr_reg));
        pb_data_output <= data_length_reg(to_integer(ctr_reg));
        if ctr_reg = 0 then
          ll_state_next <= s_send_data;
          ctr_next(15 downto 8) <= unsigned(data_length_reg(1));
          ctr_next(7 downto 0) <= unsigned(data_length_reg(0));
        end if;
        
      when s_send_data =>
        ctr_next <= ctr_reg - 1;
        pa_data_output <= data_mem_reg(to_integer(ctr_reg - 1));
        pb_data_output <= data_mem_reg(to_integer(ctr_reg - 1));
        if ctr_reg = 1 then
          ll_state_next <= s_send_crc;
          ctr_next <= to_unsigned(4-1, ctr_next'length);
        end if;
        
      when s_send_crc =>
        ctr_next <= ctr_reg - 1;
        pa_data_output <= crc_reg(to_integer(ctr_reg));
        pb_data_output <= crc_reg(to_integer(ctr_reg));
        if ctr_reg = 0 then
          ll_state_next <= s_idle;
          ctr_next <= to_unsigned(0, ctr_next'length);
        end if;

    end case;


    if src_mac_reg = MAC_TO_REPLACE then
      replace_src_mac_next <= '1';
    else
      replace_src_mac_next <= '0';
    end if;
    
    if dst_mac_reg = MAC_FOR_PB then
      packet_for_pb_next <= '1';
    else
      packet_for_pb_next <= '0';
    end if;

  end process;


  -- outputs
  o_port_a <= pa_data_output;
  o_port_b <= pb_data_output when packet_for_pb_reg = '1' else
              (others => '0');
 
  
end architecture;
