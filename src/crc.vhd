library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lab_lib;
use lab_lib.util_pkg.all;

 
entity crc is
  generic (
    BIT_COUNT : natural := 32
  );
	port (
		clk         : in sl;
		rst         : in sl;

    i_data      : in slv;
    i_valid     : in sl;
    o_ready     : out sl;
    i_srst      : in sl;

    i_polynome  : in slv(BIT_COUNT downto 0);
    o_crc       : out slv(BIT_COUNT-1 downto 0)
	);
end entity;
 
architecture RTL of crc is
  signal valid_reg, valid_next : slv(8-1 downto 0) := (others => '0');
  signal data_reg, data_next : slv(8-1 downto 0) := (others => '0');
  signal crc_reg, crc_next : slv(BIT_COUNT-1 downto 0) := (others => '0');
  signal int_en : sl := '0';
begin
  -- reg-state logic
	process(clk, rst) is
	begin
		if rst = '1' then
      valid_reg <= (others => '0');
      data_reg <= (others => '0');
      crc_reg <= (others => '0');
		elsif rising_edge(clk) then
      valid_reg <= valid_next;
      data_reg <= data_next;
      crc_reg <= crc_next;
		end if;
	end process;

  -- next-state logic
  SR_XORS: for i in 1 to BIT_COUNT-1 generate
    crc_next(i) <= '0' when i_srst = '1' else
                    crc_reg(BIT_COUNT-1) xor crc_reg(i-1) when (i_polynome(i) = '1' and int_en = '1') else
                    crc_reg(i-1) when int_en = '1' else
                    crc_reg(i);
  end generate;

  crc_next(0) <= '0' when i_srst = '1' else
                 crc_reg(BIT_COUNT-1) xor data_reg(data_reg'high) when (i_polynome(0) = '1' and int_en = '1') else
                 data_reg(data_reg'high) when int_en = '1' else
                 crc_reg(0);

  
  VALID_SR: for i in 1 to 8-1 generate
    valid_next(i) <= valid_reg(i-1);
  end generate;
  valid_next(0) <= i_valid;


  DATA_PISO: for i in 1 to 8-1 generate
    data_next(i) <= i_data(i) when i_valid = '1' else
                    data_reg(i-1);
  end generate;
  data_next(0) <= i_data(0) when i_valid = '1' else
                  '0';

  int_en <= '0' when valid_reg = x"00" else
            '1';
  -- outputs
  o_ready <= not int_en;
  o_crc <= crc_reg;
end architecture;
