---------------------------------------------------------------------------------
--
-- PROJECT:      psec4a eval
-- FILE:         psec4a_core.vhd
-- AUTHOR:       e.oberla
-- EMAIL         eric.oberla@gmail.com
-- DATE:         2/2018
--
-- DESCRIPTION:  handles psec4a sampling/digitization/readout
--
---------------------------------------------------------------------------------
library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.defs.all;

entity psec4a_core is
port(
	rst_i				:	in		std_logic;
	clk_i				: 	in 	std_logic;
	registers_i		:	in		register_array_type;
	
	dll_start_o		:	out	std_logic; --//psec4a dll reset/enable
	xfer_adr_o		:	out	std_logic_vector(3 downto 0); --//psec4a analog write address
	ramp_o			:	out	std_logic; --//psec4a ramp toggle
	ring_osc_en_o	:	out	std_logic; --//psec4a ring oscillator enable
	comp_sel_o		:	out	std_logic_vector(2 downto 0); --//psec4a comparator select
	latchsel_o		:	out	std_logic_vector(1 downto 0); --//psec4a select ADC latchsel_o
	latch_transp_o	:	out	std_logic; --//enable latch transparency
	clear_adc_o		:	out	std_logic; --//psec4a clear ADC counters
	rdout_clk_o		:  out	std_logic; --//psec4a readout clock
	chan_sel_o		:	out	std_logic_vector(2 downto 0); --//psec4a readout channel select
	
	psec4a_dat_i	:	in		std_logic_vector(10 downto 0); --//psec4a data bus
	psec4a_trig_i	:	in		std_logic_vector(7 downto 0));

end psec4a_core;

architecture rtl of psec4a_core is

begin

end rtl;
	