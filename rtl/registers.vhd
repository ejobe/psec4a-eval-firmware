---------------------------------------------------------------------------------
--
-- PROJECT:      
-- FILE:         registers.vhd
-- AUTHOR:       e.oberla
-- EMAIL         eric.oberla@gmail.com
-- DATE:         
--
-- DESCRIPTION:  
---------------------------------------------------------------------------------
--////////////////////////////////////////////////////////////////////////////
library IEEE; 
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.defs.all;

--////////////////////////////////////////////////////////////////////////////
entity registers is
	port(
		rst_powerup_i	:	in		std_logic;
		rst_i				:	in		std_logic;  --//reset
		clk_i				:	in		std_logic;  --//internal register clock 
		--////////////////////////////
		write_reg_i		:	in		std_logic_vector(31 downto 0); --//input data
		write_rdy_i		:	in		std_logic; --//data ready to be written in spi_slave
		read_reg_o 		:	out 	std_logic_vector(define_register_size-1 downto 0); --//set data here to be read out
		registers_io	:	inout	register_array_type;
		readout_register_i : in read_register_array_type;
		address_o		:	out	std_logic_vector(define_address_size-1 downto 0));
		
	end registers;

--////////////////////////////////////////////////////////////////////////////
architecture rtl of registers is
signal write_rdy_reg : std_logic_vector(1 downto 0);

begin
--/////////////////////////////////////////////////////////////////
--//write registers: 
proc_write_register : process(rst_i, clk_i, write_rdy_i, write_reg_i, registers_io, rst_powerup_i)
begin

	if rst_i = '1' then
		write_rdy_reg <= (others=>'0');
		--////////////////////////////////////////////////////////////////////////////
		--//for a few registers, only set defaults on power up:
		if rst_powerup_i = '1' then
			registers_io(1) <= firmware_version; --//firmware version (see defs.vhd)
			registers_io(2) <= firmware_date;  	 --//date             (see defs.vhd)
			registers_io(3) <= firmware_year;
		end if;
		
		--////////////////////////////////////////////////////////////////////////////
		--//read-only registers:
		for i in 0 to 31 loop
			registers_io(4+i) <= (others=>'0');
		end loop;

		
		registers_io(64) <= x"000000"; --// sw trigger
		
		registers_io(80) <= x"007359";  --//ro count target low 16 bits  ( set to 1GHz / 2^11))
		registers_io(81) <= x"000007";  --//ro count target high 16 bits
		registers_io(82) <= x"000000";  --//ro firmware feedback enable
		registers_io(83) <= x"000000";  --//trig sign (LSB)
		registers_io(84) <= x"000000";  --//dll speed select(LSB)
		registers_io(85) <= x"000000";  --//reset_xfer enable (LSB)
		--// DAC values
		registers_io(86) <= x"0002FA";  	--//ROvcp
		registers_io(87) <= x"000000";  	--//BiasTrigN
		registers_io(88) <= x"0003FF";  	--//BiasXfer
		registers_io(89) <= x"0003FA";  	--//BiasRampBuf
		registers_io(90) <= x"0003FF";	--//BiasComp
		registers_io(91) <= x"000000";   --//BiasDllLast
		registers_io(92) <= x"000000"; 	--//BiasDllFirst
		registers_io(93) <= x"0001FA";	--//BiasDllp
		registers_io(94) <= x"000000";	--//BiasDlln
		registers_io(95) <= x"000000";	--//TrigThresh1
		registers_io(96) <= x"000000";
		registers_io(97) <= x"000000";
		registers_io(98) <= x"000000";
		registers_io(99) <= x"000000";
		registers_io(100) <= x"000000";
		registers_io(101) <= x"000000";
		registers_io(102) <= x"000000";  --//TrigThresh8
		registers_io(103) <= x"000000";	--//BiasRampSlope
		--//external DAC values		
		registers_io(104) <= x"008000";	--//Vped
		registers_io(105) <= x"001000";	--//VresetXfer

		
		registers_io(109) <= x"000001";  --//read register [109]
		address_o <= x"00";
		
	elsif rising_edge(clk_i) then 
		write_rdy_reg <= write_rdy_reg(0) & write_rdy_i;
		--//initiate a read
		if write_rdy_reg(1) = '1' and write_reg_i(31 downto 24) = x"6D" then
			read_reg_o <=  write_reg_i(7 downto 0) & registers_io(to_integer(unsigned(write_reg_i(7 downto 0))));
			address_o <= x"47";  --//initiate a read
			
		--//write a register
		elsif write_rdy_reg(1) = '1' and write_reg_i(31 downto 24) > x"28" then  --//read/write registers
			registers_io(to_integer(unsigned(write_reg_i(31 downto 24)))) <= write_reg_i(23 downto 0);
			address_o <= write_reg_i(31 downto 24);
			
		else
			address_o <= x"00";
			--//assign readout only registers
			for i in 0 to 31 loop
				registers_io(4+i)(15 downto 0) <= readout_register_i(i);
			end loop;
			
			
			--////////////////////////////////////////////////
			--//update status/system read-only registers
			
			--//assign event meta data
			--for j in 0 to 24 loop
			--	registers_io(j+10) <= event_metadata_i(j);
			--end loop;
			--////////////////////////////////////////////////
			--//clear pulsed registers
			registers_io(127) <= x"000000"; --//clear the reset register
			registers_io(126) <= x"000000"; --//clear the event counter reset
			registers_io(40) <= x"000000"; --//clear the update scalers pulse
			--////////////////////////////////////////////////////////////////////////////	
			--//these should be static, but keep updating every clk_i cycle
			--if unique_chip_id_rdy = '1' then
			--	registers_io(4) <= unique_chip_id(23 downto 0);
			--	registers_io(5) <= unique_chip_id(47 downto 24);
			--	registers_io(6) <= fpga_temp_i & unique_chip_id(63 downto 48);	
			--end if;
		end if;
	end if;
end process;
--/////////////////////////////////////////////////////////////////
--//get silicon ID:
--xUNIQUECHIPID : entity work.ChipID
--port map(
--	clkin      => clk_i,
--	reset      => rst_i,
--	data_valid => unique_chip_id_rdy,
--	chip_id    => unique_chip_id);
end rtl;
--////////////////////////////////////////////////////////////////////////////