library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library lab_lib;
use lab_lib.util_pkg.all;

library vunit_lib;
context vunit_lib.vunit_context;
 
entity tb is
  generic (runner_cfg: string);
end entity;
 
architecture RTL of tb is
	constant CLK_PERIOD : time := 5 ns;

	constant QUARTER_DELAY : time := 50*CLK_PERIOD;
	constant HALF_DELAY : time := 100*CLK_PERIOD;
 
	signal clk : sl := '0';
	signal rst : sl := '1';
	signal en : sl := '1';

  signal o_port_a : slv (8-1 downto 0) := (others => '0');
  signal o_port_b : slv (8-1 downto 0) := (others => '0');
 
begin
	clk <= not clk after CLK_PERIOD/2;
	rst <= '0' after CLK_PERIOD;
	DUT: entity lab_lib.traffic_splitter
		port map(
			clk => clk,
			rst => rst,
			en => en,

      o_port_a => o_port_a,
      o_port_b => o_port_b
		);
  
  main: process

  begin
    test_runner_setup(runner, runner_cfg);
    while test_suite loop

      if run("Full_coverage") then
        wait for 100 us;
      end if;

    end loop;
    test_runner_cleanup(runner);
  end process; 
end architecture;
