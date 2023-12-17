library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lab_lib;
use lab_lib.util_pkg.all;

 
entity traffic_splitter is
	port (
		clk         : in sl;
		rst         : in sl;
		en          : in sl;

    o_port_a      : out slv;
    o_port_b      : out slv
	);
end entity;
 
architecture RTL of traffic_splitter is
  constant BYTE_COUNT : natural := etherTraff'length; 
 
  signal data_ptr_reg, data_ptr_next : unsigned(log2c(BYTE_COUNT)-1 downto 0) := (others => '0');
  signal traffic_data : slv(8-1 downto 0);
  signal EOF : boolean := false;

  signal state_reg, state_next : state_t := s_idle;
  signal ctr_reg, ctr_next : unsigned(2*8-1 downto 0) := (others => '0');

  signal dst_mac_reg, dst_mac_next : aslv(0 to 6-1)(8-1 downto 0) := (others => '0');
  signal src_mac_reg, src_mac_next : aslv(0 to 6-1)(8-1 downto 0) := (others => '0');
  signal data_length_reg, data_length_next : aslv(0 to 2-1)(8-1 downto 0) := (others => '0');
begin
  
  -- reg-state logic
	process(clk, rst) is
	begin
		if rst = '1' then
      data_ptr_reg <= (others => '0');
      ctr_reg <= (others => '0');
      dst_mac_reg <= (others => (others => '0'));
      src_mac_reg <= (others => (others => '0'));
      data_length_reg <= (others => (others => '0'));
		elsif rising_edge(clk) then
      data_ptr_reg <= data_ptr_next;
      ctr_reg <= ctr_next;
      dst_mac_reg <= dst_mac_next;
      src_mac_reg <= src_mac_next;
      data_length_reg <= data_length_next;
		end if;
	end process;

  -- reading from ROM
  traffic_data <= etherTraff(to_integer(data_ptr_reg));
 
  EOF <= data_ptr_reg = BYTE_COUNT;
  data_ptr_next <= (others => '0') when EOF else
                   data_ptr_reg + 1;

  -- next-state logic
  process(all) is
  begin
    state_next <= state_reg;
    ctr_next <= ctr_reg;
    dst_mac_next <= dst_mac_reg;
    src_mac_next <= src_mac_reg;
    data_length_next <= data_length_reg;

    case state_reg is
      when s_idle =>
        if traffic_data = x"AA" then
          state_next <= s_detect_preamble;
        end if;
      when s_detect_preamble =>
        if traffic_data = x"AB" then
          state_next <= s_read_dst_mac;
          ctr_next <= to_unsigned(6-1);
        end if;
      when s_read_dst_mac =>
        
        
      when s_read_src_mac =>

      when s_read_len =>

      when s_read_data => 

      when s_compute_crc => 
        
    end case;
  end process;
  -- outputs
  o_port_a <= traffic_data;
  o_port_b <= traffic_data;
 
end architecture;
