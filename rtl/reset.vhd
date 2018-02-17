---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    --KICP--
--
-- PROJECT:      phased-array trigger board
-- FILE:         sys_reset.vhd
-- AUTHOR:       e.oberla
-- EMAIL         ejo@uchicago.edu
-- DATE:         1/2016
--
-- DESCRIPTION:  resets
--
---------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.defs.all;

entity reset is
	Port(
		clk_i				:	in		std_logic; 
		reg_i				:	in		register_array_type;
		power_on_rst_o	:	out	std_logic;
		reset_o			:	out	std_logic);	--//active hi -- THIS IS THE GLOBAL RESET
end reset;

architecture rtl of reset is

	type 		power_on_reset_state_type is (CLEAR, READY);
	signal	power_on_reset_state	:	power_on_reset_state_type := CLEAR;
	
	signal	fpga_reset_count	:	std_logic_vector(31 downto 0) := (others=>'0');
	signal	fpga_reset_pwr		:	std_logic := '1';
	signal	fpga_reset_usr		:	std_logic := '0';
	
begin

power_on_rst_o <= fpga_reset_pwr;
reset_o			<= fpga_reset_pwr or fpga_reset_usr; --//global full reset
--//power-on RESET:
proc_reset_powerup : process(clk_i, fpga_reset_count)
begin
	if rising_edge(clk_i) then 
		case power_on_reset_state is
			when CLEAR =>
				fpga_reset_pwr <= '1';
				
				if fpga_reset_count >= x"028FFFE7" then --//about 1.7 sec at 25 MHz
					power_on_reset_state <= READY;
				else
					fpga_reset_count <= fpga_reset_count + 1;
					power_on_reset_state <= CLEAR;
				end if;
				
			when READY =>
				fpga_reset_pwr <= '0';
			
			when others=>
				null;
		end case;
	end if;
end process;

--//user-initiated global reset
xUSER_RESET : entity work.pulse_stretcher_sync(rtl)
generic map(stretch => 50000000) --//2 second reset
port map(
	rst_i		=> fpga_reset_pwr,
	clk_i		=> clk_i,
	pulse_i	=> reg_i(127)(0), --//reset bit in reset register
	pulse_o	=> fpga_reset_usr);

end rtl;
