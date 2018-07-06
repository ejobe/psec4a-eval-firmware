------------------------------
-- psec4a_eval_top.vhd
------------------------------
-- author: eric oberla
-- eric.oberla@gmail.com
-- date  : 2018-1-31, onwards

library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.defs.all;

entity psec4a_eval_top is
port(
	psec4a_write_clk_i	:	in		std_logic;  --//clock from mezzanine board
	psec4a_vcdl_output_i	:	in		std_logic;
	psec4a_read_clk_o		:	out	std_logic;
	psec4a_d_i				:	in		std_logic_vector(10 downto 0);
	psec4a_xferadr_o		:	out	std_logic_vector(3 downto 0);
	psec4a_latchsel_o		:	out	std_logic_vector(3 downto 0);
	psec4a_ringosc_en_o	:	buffer	std_logic;
	psec4a_ringosc_mon_i	:	in		std_logic;
	psec4a_trigger_i		:	in		std_logic_vector(7 downto 0);
	psec4a_compsel_o		:	out	std_logic_vector(2 downto 0);
	psec4a_chansel_o		:	out	std_logic_vector(2 downto 0);
	psec4a_rampstart_o	:	out	std_logic;
	psec4a_dllstart_o		:	out	std_logic;
	psec4a_sclk_o			:	out	std_logic;  --//serial prog clock
	psec4a_sle_o			:	out	std_logic;  --//serial prog load enable 
	psec4a_sdat_o			:	out	std_logic;  --//serial prog data
	
	--FPGA_aux_io				:	inout	std_logic;
	debug						:	inout std_logic_vector(19 downto 2);
	
	USB_IFCLK				:	inout std_logic;
	USB_WAKEUP_n			:	inout std_logic;
	USB_CTL					:	inout std_logic_vector(2 downto 0);
	USB_CLKOUT				:	in		std_logic;
	USB_PA					:	inout	std_logic_vector(7 downto 0);
	USB_FD					:	inout	std_logic_vector(15 downto 0);
	USB_RDY					:	inout	std_logic_vector(1 downto 0);
	
	led_0						:	out	std_logic;
	led_1						:	out	std_logic;
	led_2						:	out	std_logic;
	
	DACone					: inout 	std_logic_vector(4 downto 0); --//external DAC
	DACtwo					: inout 	std_logic_vector(4 downto 0); --//external DAC
	
	master_clock			: 	in		std_logic); --//clock on motherboard 
end psec4a_eval_top;

architecture rtl of psec4a_eval_top is

signal global_reset_sig	:	std_logic;
signal reset_pwrup_sig	:	std_logic;
signal clk_25MHz_sig		: 	std_logic; --//PLL output
signal clk_75MHz_sig	: 	std_logic; --//PLL output
signal clk_100kHz_sig 	:	std_logic; --//PLL output
signal clk_1Hz_sig		: 	std_logic;
signal clk_10Hz_sig		:	std_logic;
signal clk_usb_48Mhz		:	std_logic;
signal clk_reg				:	std_logic;
signal clk_mezz_internal:  std_logic;
--signal psec4a_write_clk_buf:  std_logic;

signal usb_done_sig		:	std_logic;
signal usb_slwr_sig		:	std_logic;
signal usb_instr_sig		:	std_logic_vector(31 downto 0);
signal usb_instr_rdy_sig:	std_logic;
signal usb_start_wr_sig	:	std_logic;

signal psec4a_read_clk 	:  std_logic;
signal psec4a_readout_valid : std_logic;
signal psec4a_chan_sel 	:  std_logic_vector(2 downto 0);
signal data_fifo_rd_empty : std_logic;
signal data_fifo_clk	: std_logic;
signal data_fifo_data : std_logic_vector(15 downto 0);
signal data_ram_rd_addr : std_logic_vector(10 downto 0);
signal data_ram_wr_addr : std_logic_vector(10 downto 0);

signal register_array 	:	register_array_type;
signal reg_addr_sig		:  std_logic_vector(define_address_size-1 downto 0);
signal readout_reg_sig  :  std_logic_vector(define_register_size-1 downto 0);
signal usb_dataout_sig	:  std_logic_vector(15 downto 0);
signal usb_readout_length : std_logic_vector(15 downto 0);

signal refresh_clk_1Hz				: std_logic := '0';
signal refresh_clk_counter_1Hz 	: std_logic_vector(19 downto 0);
signal refresh_clk_10Hz				: std_logic := '0';
signal refresh_clk_counter_10Hz 	: std_logic_vector(19 downto 0);
signal REFRESH_CLK_MATCH_1HZ		: std_logic_vector(19 downto 0) := x"186A0";
signal REFRESH_CLK_MATCH_10HZ		: std_logic_vector(19 downto 0) := x"02710";

--//1hz pulse on the register clock
signal refresh_clk_reg_1Hz				: std_logic := '0';
signal refresh_clk_reg_counter_1Hz 	: std_logic_vector(27 downto 0);
signal REFRESH_CLK_REG_MATCH_1HZ		: std_logic_vector(27 downto 0) := x"2DC6C00";

signal readout_register_array : read_register_array_type;
--//---------------------------------------------------------------------------
begin

xCLK_GEN_10Hz : entity work.Slow_Clocks
generic map(clk_divide_by => 5000)
port map(clk_100kHz_sig, global_reset_sig, clk_10Hz_sig);
		
xCLK_GEN_1Hz : entity work.Slow_Clocks
generic map(clk_divide_by => 50000)
port map(clk_100kHz_sig, global_reset_sig, clk_1Hz_sig);

xRESET : entity work.reset
port map(
	clk_i	=> clk_25MHz_sig, reg_i=>register_array, 
	power_on_rst_o => reset_pwrup_sig, reset_o => global_reset_sig);
	
proc_make_refresh_pulse : process(clk_100kHz_sig)
begin
	if rising_edge(clk_100kHz_sig) then			
		if refresh_clk_1Hz = '1' then
			refresh_clk_counter_1Hz <= (others=>'0');
		else
			refresh_clk_counter_1Hz <= refresh_clk_counter_1Hz + 1;
		end if;
		--//pulse refresh when refresh_clk_counter = REFRESH_CLK_MATCH
		case refresh_clk_counter_1Hz is
			when REFRESH_CLK_MATCH_1HZ =>
				refresh_clk_1Hz <= '1';
			when others =>
				refresh_clk_1Hz <= '0';
		end case;
		
		if refresh_clk_10Hz = '1' then
			refresh_clk_counter_10Hz <= (others=>'0');
		else
			refresh_clk_counter_10Hz <= refresh_clk_counter_10Hz + 1;
		end if;
		--//pulse refresh when refresh_clk_counter = REFRESH_CLK_MATCH
		case refresh_clk_counter_10Hz is
			when REFRESH_CLK_MATCH_10HZ =>
				refresh_clk_10Hz <= '1';
			when others =>
				refresh_clk_10Hz <= '0';
		end case;
	end if;
end process;

--//refresh pulse for scalers:
--proc_make_refresh_pulse_2 : process(clk_reg)
--begin
--	if rising_edge(clk_reg) then			
--		if refresh_clk_reg_1Hz = '1' then
--			refresh_clk_reg_counter_1Hz <= (others=>'0');
--		else
--			refresh_clk_reg_counter_1Hz <= refresh_clk_reg_counter_1Hz + 1;
--		end if;
--		--//pulse refresh when refresh_clk_counter = REFRESH_CLK_MATCH
--		case refresh_clk_reg_counter_1Hz is
--			when REFRESH_CLK_REG_MATCH_1HZ =>
--				refresh_clk_reg_1Hz <= '1';
--			when others =>
--				refresh_clk_reg_1Hz <= '0';
--		end case;
--	end if;
--end process;

xPLL0 : entity work.pll0
port map(
	areset => '0', inclk0 => master_clock,
	c0	=> clk_25MHz_sig, c1	=> clk_100kHz_sig, c2 => clk_75MHz_sig, locked	=> open);

----ooof, psec4a_write_clk_i not on a clk_buffer pin...this doesn't work
--xIBUF : entity work.ibuf
--port map( datain(0) => psec4a_write_clk_i, dataout(0) => psec4a_write_clk_buf);
--xPLL2 : entity work.pll2
--port map(
--	areset	=> global_reset_sig, inclk0	=> psec4a_write_clk_buf,
--	c0			=> clk_mezz_internal, locked	=> open);
clk_mezz_internal <= psec4a_write_clk_i;
--xPLL1 : entity work.pll1
--port map(
--	areset	=> '0',	inclk0	=> USB_IFCLK,
--	c0			=> clk_usb_48Mhz,	locked	=> open);

--//assign register clock:
clk_reg <= clk_usb_48Mhz;	
--//
clk_usb_48Mhz <= USB_IFCLK;
USB_RDY(1) <= usb_slwr_sig;

psec4a_read_clk_o <= psec4a_read_clk;
psec4a_chansel_o  <= psec4a_chan_sel;

xPSEC4A_CNTRL : entity work.psec4a_core 
port map(
	rst_i				=> global_reset_sig,
	clk_i				=> clk_25MHz_sig,
	clk_reg_i		=> clk_reg,
	clk_mezz_i		=> clk_mezz_internal,
	registers_i		=> register_array,
	psec4a_stat_o	=> readout_register_array(8),
	trigbits_i		=> psec4a_trigger_i,
	trig_for_scaler_o => open,
	dll_start_o		=> psec4a_dllstart_o,
	xfer_adr_o		=> psec4a_xferadr_o,
	ramp_o			=> psec4a_rampstart_o,
	ring_osc_en_o	=> psec4a_ringosc_en_o,
	comp_sel_o		=> psec4a_compsel_o,
	latch_sel_o		=> psec4a_latchsel_o, 
	rdout_clk_o		=> psec4a_read_clk,
	rdout_valid_o  => psec4a_readout_valid,
	rdout_ram_wr_addr_o => data_ram_wr_addr,
	chan_sel_o		=> psec4a_chan_sel);

--xPSEC4A_DATA : entity work.psec4a_data
--port map(
--	rst_i				=> global_reset_sig,
--	wrclk_i			=> psec4a_read_clk,
--	registers_i		=> register_array,
--	psec4a_dat_i	=> psec4a_d_i,
--	psec4a_ch_sel_i=> psec4a_chan_sel,
--	data_valid_i	=> psec4a_readout_valid,
--	fifo_clk_i		=> data_fifo_clk,
--	fifo_used_words_o => readout_register_array(5),
--	fifo_rd_empty_o => data_fifo_rd_empty,
--	fifo_rd_data_o	=>  data_fifo_data);
xPSEC4A_DATA : entity work.psec4a_data_ram
port map(	
	rst_i				=> global_reset_sig,	
	wrclk_i			=> psec4a_read_clk,
	registers_i		=> register_array,
	psec4a_dat_i	=> psec4a_d_i,
	psec4a_ch_sel_i=> psec4a_chan_sel,
	data_valid_i	=> psec4a_readout_valid,
	ram_clk_i		=> usb_slwr_sig,
	ram_rd_addr_i	=> data_ram_rd_addr,
	ram_wr_addr_i	=> data_ram_wr_addr,
	ram_rd_data_o	=> data_fifo_data);

xUSB : entity work.usb_32bit
port map(
	CORE_CLK				=> clk_reg, --clk_25MHz_sig,
	USB_IFCLK			=> clk_usb_48Mhz,	
	USB_RESET    		=> global_reset_sig,  
	USB_BUS  			=> USB_FD,  
	FPGA_DATA			=> usb_dataout_sig, 
   USB_FLAGB    		=> USB_CTL(1),		
   USB_FLAGC    		=> USB_CTL(2),		
	USB_START_WR		=> usb_start_wr_sig,		
	USB_NUM_WORDS		=> usb_readout_length,
   USB_DONE  			=> usb_done_sig,	   
   USB_PKTEND    		=> USB_PA(6),	
   USB_SLWR  			=> usb_slwr_sig,		
   USB_WBUSY 			=> open,     			
   USB_FLAGA    		=> USB_CTL(0),   
   USB_FIFOADR  		=> USB_PA(5 downto 4),
   USB_SLOE     		=> USB_PA(2),
   USB_SLRD     		=> USB_RDY(0),		
   USB_RBUSY 			=> open,		
   USB_INSTRUCTION	=> usb_instr_sig,
	USB_INSTRUCT_RDY	=> usb_instr_rdy_sig);
	
xREGISTERS : entity work.registers
port map(
		rst_powerup_i	=> reset_pwrup_sig,	
		rst_i				=> global_reset_sig,
		clk_i				=> clk_reg, --clk_25MHz_sig,
		write_reg_i		=> usb_instr_sig,
		write_rdy_i		=> usb_instr_rdy_sig,
		read_reg_o 		=> readout_reg_sig,
		registers_io	=> register_array,
		readout_register_i => readout_register_array,
		address_o		=> reg_addr_sig);
		
--xRDOUT_CNTRL : entity work.rdout_controller_v2 
--	port map(
--		rst_i					=> global_reset_sig,	
--		clk_i					=> clk_usb_48Mhz, --clk_25MHz_sig,					
--		rdout_reg_i			=> readout_reg_sig,	
--		reg_adr_i			=> reg_addr_sig,	
--		registers_i			=> register_array,	   
--		usb_slwr_i			=> usb_slwr_sig,
--		tx_rdy_o				=> usb_start_wr_sig,	
--		tx_ack_i				=> usb_done_sig,
--		data_fifo_i			=> data_fifo_data,
--		data_fifo_empty_i	=> data_fifo_rd_empty,
--		data_fifo_clk_o	=> data_fifo_clk,
--		rdout_length_o		=> usb_readout_length,
--		rdout_fpga_data_o	=> usb_dataout_sig);	
xRDOUT_CNTRL : entity work.rdout_controller_v3 
	port map(
		rst_i					=> global_reset_sig,	
		clk_i					=> clk_reg, --clk_25MHz_sig,					
		rdout_reg_i			=> readout_reg_sig,	
		reg_adr_i			=> reg_addr_sig,	
		registers_i			=> register_array,	   
		usb_slwr_i			=> usb_slwr_sig,
		tx_rdy_o				=> usb_start_wr_sig,	
		tx_ack_i				=> usb_done_sig,
		data_rd_addr_o		=> data_ram_rd_addr,
		data_fifo_i			=> data_fifo_data,
		rdout_length_o		=> usb_readout_length,
		rdout_fpga_data_o	=> usb_dataout_sig);	
		
xPSEC4A_SERIAL : entity work.psec4a_serial
port map(		
	clk_i				=> clk_100kHz_sig,
	rst_i				=> global_reset_sig,
	registers_i		=> register_array,
	write_i			=> refresh_clk_1Hz,
	psec4a_ro_bit_i => psec4a_ringosc_mon_i, --//ring oscillator divider bit
	psec4a_ro_count_lo_o => readout_register_array(0),
	psec4a_ro_count_hi_o => readout_register_array(1),
	serial_clk_o	=> psec4a_sclk_o,
	serial_le_o		=> psec4a_sle_o,
	serial_dat_o	=> psec4a_sdat_o);
	
xLTC2600 : entity work.DAC_MAIN_LTC2600
port map(
	xCLKDAC			=> clk_100kHz_sig,
	xCLK_REFRESH	=> refresh_clk_1Hz,
	xCLR_ALL			=> global_reset_sig,
	registers_i		=> register_array,
	SDATOUT1			=> DACone(2),
	SDATOUT2			=> DACtwo(2),
	DACCLK1			=> DACone(0),
	DACCLK2			=> DACtwo(0),
	LOAD1				=> DACone(4),
	LOAD2				=> DACtwo(4),
	CLR_BAR1			=> DACone(3),
	CLR_BAR2			=> DACtwo(3),
	SDATIN1			=> DACone(1),
	SDATIN2			=> DACtwo(1));
		
led_0 <= not global_reset_sig;
led_1 <= clk_10Hz_sig;
led_2 <= not usb_start_wr_sig;

debug(2) <= psec4a_ringosc_en_o;

end rtl;