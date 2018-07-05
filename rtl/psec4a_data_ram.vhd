---------------------------------------------------------------------------------
--
-- PROJECT:      psec4a eval
-- FILE:         psec4a_data.vhd
-- AUTHOR:       e.oberla
-- EMAIL         eric.oberla@gmail.com
-- DATE:         3/2018...
--
-- DESCRIPTION:  handles psec4a data
--
---------------------------------------------------------------------------------
library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.defs.all;

entity psec4a_data_ram is
port(
	rst_i				:	in		std_logic;
	wrclk_i			:	in		std_logic;
	registers_i		:	in		register_array_type;
	psec4a_dat_i	:	in		std_logic_vector(psec4a_num_adc_bits-1 downto 0); --//psec4a data bus
	psec4a_ch_sel_i:	in		std_logic_vector(2 downto 0);
	data_valid_i	:	in		std_logic;
	ram_clk_i		:	in		std_logic;
	ram_rd_addr_i	:	in		std_logic_vector(10 downto 0);
	ram_wr_addr_i	:	in		std_logic_vector(10 downto 0);
	ram_rd_data_o	:	out	std_logic_vector(15 downto 0));

end psec4a_data_ram;

architecture rtl of psec4a_data_ram is

type ram_data_type is array(psec4a_num_channels-1 downto 0) of std_logic_vector(13 downto 0);
signal ram_out_data : ram_data_type;

signal ram_wr_addr : std_logic_vector(10 downto 0) := (others=>'0');
signal ram_wr_en : std_logic_vector(psec4a_num_channels-1 downto 0);
signal ram_rd_en : std_logic_vector(psec4a_num_channels-1 downto 0);

begin

process(rst_i, psec4a_ch_sel_i)
begin
case psec4a_ch_sel_i is
	when "000"=> ram_wr_en <= x"01";
	when "001"=> ram_wr_en <= x"02";
	when "010"=> ram_wr_en <= x"04";
	when "011"=> ram_wr_en <= x"08";
	when "100"=> ram_wr_en <= x"10";
	when "101"=> ram_wr_en <= x"20";
	when "110"=> ram_wr_en <= x"40";
	when "111"=> ram_wr_en <= x"80";
end case;
end process;
--
process(rst_i, registers_i(72))
begin
case registers_i(72)(3 downto 0) is
	when x"0" => ram_rd_en <= x"00"; ram_rd_data_o <= (others=>'0'); 
	when x"1" => ram_rd_en <= x"01"; ram_rd_data_o <= "00" & ram_out_data(0); 
	when x"2" => ram_rd_en <= x"02"; ram_rd_data_o <= "00" & ram_out_data(1); 
	when x"3" => ram_rd_en <= x"04"; ram_rd_data_o <= "00" & ram_out_data(2); 
	when x"4" => ram_rd_en <= x"08"; ram_rd_data_o <= "00" & ram_out_data(3); 
	when x"5" => ram_rd_en <= x"10"; ram_rd_data_o <= "00" & ram_out_data(4); 
	when x"6" => ram_rd_en <= x"20"; ram_rd_data_o <= "00" & ram_out_data(5); 
	when x"7" => ram_rd_en <= x"40"; ram_rd_data_o <= "00" & ram_out_data(6); 
	when x"8" => ram_rd_en <= x"80"; ram_rd_data_o <= "00" & ram_out_data(7); 
	when others=> ram_rd_en <= x"00"; ram_rd_data_o <= (others=>'0'); 
end case; 
end process;
--
--
RX_DATA_RAM : for i in 0 to psec4a_num_channels-1 generate
	xPSEC4A_DATA_RAM : entity work.ram
	port map(	
		data		=> '0' & registers_i(12)(0) & '0' & psec4a_dat_i, --//buffer number saved w/ data
		rdaddress	=> ram_rd_addr_i,
		rdclock	=> ram_clk_i,
		rden		=> ram_rd_en(i),
		wraddress	=> ram_wr_addr_i,
		wrclock		=> wrclk_i,
		wren		=> ram_wr_en(i) and data_valid_i,
		q		=> ram_out_data(i));
end generate;
--
end rtl;