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
	clk_i				:	in		std_logic;
	psec4a_dat_i	:	in		std_logic_vector(10 downto 0); --//psec4a data bus
	
	fifo_wr_en_i	: 	in		std_logic_vector(psec4a_num_channels-1 downto 0);
	fifo_rd_en_i	: 	in		std_logic_vector(psec4a_num_channels-1 downto 0);
	fifo_rd_clk		:	in		std_logic;
	fifo_rd_data_o	:	out	std_logic_vector(10 downto 0));

end psec4a_data;

architecture rtl of psec4a_data is

begin

RX_DATA_FIFO : for i in 0 to psec4a_num_channels-1 generate
	xPSEC4A_DATA_FIFO : entity work.fifo
	port map(	
		aclr		=> rst_i,
		data		=> psec4a_dat_i,
		rdclk		=> fifo_rd_clk,
		rdreq		=> fifo_rd_en_i(i),
		wrclk		=> clk_i,
		wrreq		=> fifo_wr_en_i(i),
		q			=> fifo_rd_data_o,
		rdempty	=> open,	
		rdusedw	=> open,
		wrfull	=> open); 
end generate;


end rtl;