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

entity psec4a_data is
port(
	rst_i				:	in		std_logic;
	wrclk_i			:	in		std_logic;
	registers_i		:	in		register_array_type;
	psec4a_dat_i	:	in		std_logic_vector(psec4a_num_adc_bits-1 downto 0); --//psec4a data bus
	psec4a_ch_sel_i:	in		std_logic_vector(2 downto 0);
	data_valid_i	:	in		std_logic;
	fifo_clk_i		:	in		std_logic;
	fifo_used_words_o : out  std_logic_vector(15 downto 0);
	fifo_rd_empty_o : out std_logic;
	fifo_rd_data_o	:	out	std_logic_vector(15 downto 0));

end psec4a_data;

architecture rtl of psec4a_data is

type fifo_data_type is array(psec4a_num_channels-1 downto 0) of std_logic_vector(psec4a_num_adc_bits-1 downto 0);
signal fifo_out_data : fifo_data_type;
signal fifo_in_data : fifo_data_type;

type fifo_depth_type is array(psec4a_num_channels-1 downto 0) of std_logic_vector(10 downto 0);
signal used_words : fifo_depth_type;
signal empty : std_logic_vector(psec4a_num_channels-1 downto 0);

signal fifo_wr_en : std_logic_vector(psec4a_num_channels-1 downto 0);
signal fifo_rd_en : std_logic_vector(psec4a_num_channels-1 downto 0);

begin

process(rst_i, psec4a_ch_sel_i)
begin
case psec4a_ch_sel_i is
	when "000"=> fifo_wr_en <= x"01";
	when "001"=> fifo_wr_en <= x"02";
	when "010"=> fifo_wr_en <= x"04";
	when "011"=> fifo_wr_en <= x"08";
	when "100"=> fifo_wr_en <= x"10";
	when "101"=> fifo_wr_en <= x"20";
	when "110"=> fifo_wr_en <= x"40";
	when "111"=> fifo_wr_en <= x"80";
end case;
end process;
--
process(rst_i, registers_i(72))
begin
case registers_i(72)(3 downto 0) is
	when x"0" => fifo_rd_en <= x"00"; fifo_rd_data_o <= (others=>'0'); fifo_used_words_o<=(others=>'0'); fifo_rd_empty_o <= '0';
	when x"1" => fifo_rd_en <= x"01"; fifo_rd_data_o <= "00000" & fifo_out_data(0); fifo_used_words_o <= "00000" & used_words(0); 
					 fifo_rd_empty_o <= empty(0);
	when x"2" => fifo_rd_en <= x"02"; fifo_rd_data_o <= "00000" & fifo_out_data(1); fifo_used_words_o <= "00000" & used_words(1);
					 fifo_rd_empty_o <= empty(1);
	when x"3" => fifo_rd_en <= x"04"; fifo_rd_data_o <= "00000" & fifo_out_data(2); fifo_used_words_o <= "00000" & used_words(2);
					 fifo_rd_empty_o <= empty(2);
	when x"4" => fifo_rd_en <= x"08"; fifo_rd_data_o <= "00000" & fifo_out_data(3); fifo_used_words_o <= "00000" & used_words(3);
					 fifo_rd_empty_o <= empty(3);
	when x"5" => fifo_rd_en <= x"10"; fifo_rd_data_o <= "00000" & fifo_out_data(4); fifo_used_words_o <= "00000" & used_words(4);
					 fifo_rd_empty_o <= empty(4);
	when x"6" => fifo_rd_en <= x"20"; fifo_rd_data_o <= "00000" & fifo_out_data(5); fifo_used_words_o <= "00000" & used_words(5);
					 fifo_rd_empty_o <= empty(5);
	when x"7" => fifo_rd_en <= x"40"; fifo_rd_data_o <= "00000" & fifo_out_data(6); fifo_used_words_o <= "00000" & used_words(6);
					 fifo_rd_empty_o <= empty(6);
	when x"8" => fifo_rd_en <= x"80"; fifo_rd_data_o <= "00000" & fifo_out_data(7); fifo_used_words_o <= "00000" & used_words(7);
	             fifo_rd_empty_o <= empty(7);
	when others=> fifo_rd_en <= x"00"; fifo_rd_data_o <= (others=>'0'); fifo_used_words_o<=(others=>'0'); fifo_rd_empty_o <= '0';
end case; 
end process;
--
RX_DATA_FIFO : for i in 0 to psec4a_num_channels-1 generate
	xPSEC4A_DATA_FIFO : entity work.fifo
	port map(	
		aclr		=> rst_i or registers_i(121)(0),
		data		=> psec4a_dat_i,
		rdclk		=> fifo_clk_i, --registers_i(122)(0) or fifo_clk_i,
		rdreq		=> fifo_rd_en(i),
		wrclk		=> wrclk_i,
		wrreq		=> fifo_wr_en(i) and data_valid_i,
		q			=> fifo_out_data(i),
		rdempty	=> empty(i),	
		rdusedw	=> used_words(i),
		wrfull	=> open); 
end generate;
--
end rtl;