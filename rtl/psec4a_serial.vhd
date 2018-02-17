---------------------------------------------------------------------------------
--
-- PROJECT:      psec4a eval
-- FILE:         psec4a_serial.vhd
-- AUTHOR:       e.oberla
-- EMAIL         eric.oberla@gmail.com
-- DATE:         2/2018
--
-- DESCRIPTION:  
--
---------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.defs.all; 

entity psec4a_serial is
port(
	clk_i				:	in		std_logic;  --//clock for serial interface
	rst_i				:	in		std_logic;	
	registers_i		:	in		register_array_type;
	write_i			:	in		std_logic;
	
	serial_clk_o	:	out	std_logic;
	serial_le_o		:	out	std_logic;
	serial_dat_o	:	out	std_logic);	
				
end psec4a_serial;

architecture rtl of psec4a_serial is

signal dac_values : psec4a_dac_array_type;
constant num_nondac_bits : integer := 6;
constant num_serial_clks : integer := psec4a_num_dacs * psec4a_dac_bits+num_nondac_bits;

signal flat_serial_array_meta : std_logic_vector(num_serial_clks-1 downto 0) := (others=>'1');
signal flat_serial_array_reg : std_logic_vector(num_serial_clks-1 downto 0) := (others=>'1');

begin

proc_get_dac_values : process(rst_i, clk_i)
begin
	if rising_edge(clk_i) then
		flat_serial_array_reg <= flat_serial_array_meta;
		--//assign DAC values to long serial array:
		
		flat_serial_array_meta(0) <= registers_i(83)(0); --//trig_sign
		flat_serial_array_meta(1) <= registers_i(85)(0); --//use_reset_xfer
		flat_serial_array_meta(2) <= '0'; --// n/a
		flat_serial_array_meta(3) <= registers_i(84)(0); --//dll_speed select
		flat_serial_array_meta(4) <= '0'; --// n/a
		flat_serial_array_meta(5) <= '0'; --// n/a

		--//loop thru 10-bit DACs
		for i in 0 to psec4a_num_dacs-1 loop
			flat_serial_array_meta(num_nondac_bits+psec4a_dac_bits*(i+1)-1 downto num_nondac_bits+psec4a_dac_bits*i)
				<= registers_i(86+i)(psec4a_dac_bits-1 downto 0); 
				--<= "1010011000";
				--<= "1000000000";
		end loop;
	end if;
end process;


xSPI_WRITE : entity work.spi_write(rtl)
generic map(
		data_length => num_serial_clks,
		le_init_lev => '1')
port map(
		rst_i		=> rst_i,
		clk_i		=> clk_i,
		pdat_i	=> flat_serial_array_reg,		
		write_i	=> write_i,
		done_o	=> open,		
		sdata_o	=> serial_dat_o,
		sclk_o	=> serial_clk_o,
		le_o		=> serial_le_o);
		
end rtl;

