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
	clk_i				:	in		std_logic;  --//clock for psec4a serial interface
	rst_i				:	in		std_logic;	
	registers_i		:	in		register_array_type;
	write_i			:	in		std_logic;
	psec4a_ro_bit_i:	in		std_logic;
	
	psec4a_ro_count_lo_o :	out		std_logic_vector(15 downto 0);
	psec4a_ro_count_hi_o :	out		std_logic_vector(15 downto 0);

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

signal feedback_rovcp_dac_value : std_logic_vector(psec4a_dac_bits-1 downto 0);
signal enable_rovcp_feedback : std_logic;
signal target_ro_counter_val : std_logic_vector(31 downto 0);
signal current_ro_counter_val : std_logic_vector(31 downto 0);

begin

proc_get_dac_values : process(rst_i, clk_i)
begin
	if falling_edge(clk_i) then
		enable_rovcp_feedback <= registers_i(82)(0);
		target_ro_counter_val <= registers_i(81)(15 downto 0) & registers_i(80)(15 downto 0);

		psec4a_ro_count_lo_o <= current_ro_counter_val(15 downto 0);
		psec4a_ro_count_hi_o <= current_ro_counter_val(31 downto 16);

		--//re-clock to safely register the serial bits on the psec4a serial clock
		flat_serial_array_reg <= flat_serial_array_meta;
		
		--//assign DAC values to long serial array:
		flat_serial_array_meta(0) <= registers_i(83)(0); --//trig_sign
		flat_serial_array_meta(1) <= registers_i(85)(0); --//use_reset_xfer
		flat_serial_array_meta(2) <= '0'; --// n/a
		flat_serial_array_meta(3) <= registers_i(84)(0); --//dll_speed select
		flat_serial_array_meta(4) <= '0'; --// n/a
		flat_serial_array_meta(5) <= '0'; --// n/a

		--//loop thru 10-bit DACs
		-------------------------------------------
		--//handle the rovcp value separately, as it can be programmed by software OR the internal feedback lop
		if enable_rovcp_feedback = '1' then
			flat_serial_array_meta(num_nondac_bits+psec4a_dac_bits-1 downto num_nondac_bits) <= feedback_rovcp_dac_value; 
		else 
			flat_serial_array_meta(num_nondac_bits+psec4a_dac_bits-1 downto num_nondac_bits) <= registers_i(86)(psec4a_dac_bits-1 downto 0); 
		end if;
		--other DAC values:
		for i in 1 to psec4a_num_dacs-1 loop		
			flat_serial_array_meta(num_nondac_bits+psec4a_dac_bits*(i+1)-1 downto num_nondac_bits+psec4a_dac_bits*i)
				<= registers_i(86+i)(psec4a_dac_bits-1 downto 0); 
				--<= "1010011000";
				--<= "1000000000";
		end loop;
		--------------------------------------------
	end if;
end process;

--//feedback for the psec4a ring oscilator // enabled  using register 82
xRINGOSC_FEEDBACK : entity work.wilkinson_feedback_loop
port map(
	ENABLE_FEEDBACK     	=> enable_rovcp_feedback,
   RESET_FEEDBACK      	=> '0',
   REFRESH_CLOCK       	=> write_i, 
   DAC_SYNC_CLOCK      	=> write_i,
   WILK_MONITOR_BIT    	=> psec4a_ro_bit_i,
   DESIRED_COUNT_VALUE  => target_ro_counter_val,
   CURRENT_COUNT_VALUE  => current_ro_counter_val,
   DESIRED_DAC_VALUE    => feedback_rovcp_dac_value);

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

