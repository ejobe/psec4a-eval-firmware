---------------------------------------------------------------------------------

--
-- PROJECT:     
-- FILE:         rdout_controller.vhd
-- AUTHOR:       e.oberla
-- EMAIL         ejo@uchicago.edu
-- DATE:         
--
-- DESCRIPTION:  
--
---------------------------------------------------------------------------------

library IEEE; 
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.defs.all;

entity rdout_controller_v2 is	
	generic(
		d_width : INTEGER := 16);
	port(
		rst_i						:	in		std_logic;	--//asynch reset to block
		clk_i						:  in		std_logic; 	--//clock (probably 1-10 MHz, same freq range as registers.vhd and spi_slave.vhd)					
		rdout_reg_i				:	in		std_logic_vector(define_register_size-1 downto 0); --//register to readout
		reg_adr_i				:	in		std_logic_vector(define_address_size-1 downto 0);  --//firmware register addresses
		registers_i				:	in		register_array_type;   --//firmware register array      
		
		usb_slwr_i				:	in		std_logic; --//usb data clk (falling edge)
		
		tx_rdy_o					:	inout	std_logic;  --// tx ready flag
		tx_ack_i					:	in		std_logic;  --//tx ack from spi_slave (newer spi_slave module ONLY)
	
		rdout_fpga_data_o		:	out		std_logic_vector(d_width-1 downto 0)); --//data to send off-fpga
		
end rdout_controller_v2;

architecture rtl of rdout_controller_v2 is

type readout_state_type is (idle_st, single_tx_st, wait_for_ack_st);
signal readout_state : readout_state_type;

signal readout_value 	: std_logic_vector(d_width-1 downto 0);
signal usb_rdout_counter : std_logic_vector(23 downto 0);

begin

--//this is not optimal firmware here, but it should work
proc_usb_read : process(rst_i, usb_slwr_i, tx_rdy_o, tx_ack_i)
begin
	if rst_i = '1' or tx_ack_i = '1' then
		rdout_fpga_data_o <= (others=>'0');
		usb_rdout_counter <= (others=>'0');
	elsif falling_edge(usb_slwr_i) then
		if usb_rdout_counter = 0 then
			rdout_fpga_data_o <= x"DEAD";
		elsif usb_rdout_counter = 1 then
			rdout_fpga_data_o <= readout_value;
		else
			rdout_fpga_data_o <= x"BEEF";
		end if;
		usb_rdout_counter <= usb_rdout_counter + 1;
	end if;
end process;

--///////////////////////////////
--//readout process, this is on the register clock	
proc_read : process(rst_i, clk_i, reg_adr_i)
variable i : integer range 0 to 10 := 0;
begin
	if rst_i = '1' or reg_adr_i = x"48" then 
		tx_rdy_o <= '0'; 								--//tx flag to spi_slave
		readout_value <= (others=>'0');
		i := 0;
		readout_state <= idle_st;
		
	elsif rising_edge(clk_i) then
		
		case readout_state is
			--// wait for start-readout register to be written
			when idle_st =>
				tx_rdy_o <= '0';
				i := 0;
				--///////////////////////////////////////////////
				--//if readout register is written, and spi interface is done with last transfer we initiate a transfer:
				if reg_adr_i = x"47" then
					readout_state <= single_tx_st;
				else 
					readout_state <= idle_st;
				end if;
			
			when single_tx_st =>
				i := 0;
				tx_rdy_o <= '1';  --//pulse tx ready for a single clk cycle
				readout_value <= rdout_reg_i(d_width-1 downto 0); --//latch the readout value
				readout_state <= wait_for_ack_st;
			
			when wait_for_ack_st =>
				i := 0;
				--tx_rdy_o <= '0';
				if tx_ack_i = '1' then
					readout_state <= idle_st;
				end if;
				
			when others=>
				readout_state <= idle_st;
				
		end case;
	end if;
end process;

end rtl;