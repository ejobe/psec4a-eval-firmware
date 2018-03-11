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
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.defs.all;

entity psec4a_core is
port(
	rst_i				:	in		std_logic;
	clk_i				:	in		std_logic;
	clk_reg_i		: 	in 	std_logic;  --//clock for register stuff
	clk_mezz_i		:	in		std_logic;  --//clock from mezzanine board on which psec4a is using for sampling
	registers_i		:	in		register_array_type;
	
	dll_start_o		:	out	std_logic; --//psec4a dll reset/enable
	xfer_adr_o		:	buffer	std_logic_vector(3 downto 0); --//psec4a analog write address
	ramp_o			:	out	std_logic; --//psec4a ramp toggle
	ring_osc_en_o	:	out	std_logic; --//psec4a ring oscillator enable
	comp_sel_o		:	buffer	std_logic_vector(2 downto 0); --//psec4a comparator select
	latchsel_o		:	out	std_logic_vector(1 downto 0); --//psec4a select ADC latchsel_o
	latch_transp_o	:	out	std_logic; --//enable latch transparency
	clear_adc_o		:	out	std_logic; --//psec4a clear ADC counters
	clear_rdout_o	:	out	std_logic;
	rdout_clk_o		:  out	std_logic; --//psec4a readout clock
	rdout_token_o	:	out	std_logic;
	chan_sel_o		:	buffer	std_logic_vector(2 downto 0); --//psec4a readout channel select
	
	psec4a_dat_i	:	in		std_logic_vector(10 downto 0); --//psec4a data bus
	psec4a_trig_i	:	in		std_logic_vector(5 downto 0)); --//(whoops, only 6/8 trig lines routed on the board)

end psec4a_core;

architecture rtl of psec4a_core is

signal sw_trig_flag_int : std_logic; --//sw trigger flag transferred to clk_mezz_i
signal sample_hold_int : std_logic;  --//signal high to hold psec4a sampling
signal sample_rdy_int : std_logic; --//flag to restart psec4a sampling

signal psec4a_digz_busy_int : std_logic;  --//psec4a is digitizing
signal psec4a_rdout_busy_int : std_logic; --//psec4a is reading out data

signal conv_counter_int : std_logic_vector(15 downto 0) := (others=>'0');
signal conv_start_count_int : std_logic_vector(15 downto 0);
signal rdout_clk_count_int : std_logic_vector(15 downto 0) := x"84"; --//132 clk cycles per readout
signal ramp_length_count_int : std_logic_vector(15 downto 0);

signal rdout_clk_en_int : std_logic;

--//ADC counter latches can be controlled by ADC or readout
signal digz_latch_sel	 : std_logic_vector(1 downto 0);	
signal digz_latch_transp : std_logic;
signal latch_full : std_logic_vector(3 downto 0) := (others=>'0');

--//psec4a A/D conversion fsm:
--type psec4a_conversion_state_type is (idle_st, start_st, digitize_st, latch_st, wait_for_rdout_st);
--signal psec4a_conversion_state : psec4a_conversion_state_type;
type psec4a_conversion_state_type is (idle_st, start_st, ramp_st, load_latch0_st, load_latch1_st, load_latch2_st, load_latch3_st, 
												next_load_latch_st, readout_st, empty_latch0_st, empty_latch1_st, empty_latch2_st, 
												readout_channel_update_st);
												
signal psec4a_conversion_state : psec4a_conversion_state_type;
signal psec4a_next_load_latch_state: psec4a_conversion_state_type;
signal psec4a_next_empty_latch_state: psec4a_conversion_state_type;

--//psec4a readout fsm:
type psec4a_rdout_state_type is (idle_st, start_st, digitize_st, latch_st, wait_for_rdout_st);
signal psec4a_rdout_state : psec4a_rdout_state_type;

component flag_sync is
port(
	clkA			: in	std_logic;
	clkB			: in	std_logic;
	in_clkA		: in	std_logic;
	busy_clkA	: out	std_logic;
	out_clkB		: out	std_logic);
end component;

component signal_sync is
port(
	clkA			: in	std_logic;
	clkB			: in	std_logic;
	SignalIn_clkA	: in	std_logic;
	SignalOut_clkB	: out	std_logic);
end component;
	
begin

rdout_clk_o < clk_i and rdout_clk_en_int;

xSW_TRIG_SYNC : flag_sync
port map(clkA => clk_reg_i, clkB=> clk_mezz_i, in_clkA=>registers_i(124)(0),
			out_clkB => sw_trig_flag_int);
	
----------------------------------------------------------------------------------
--//PRIMARY SAMPLING and TRANSFER CONTROL NEEDS TO BE CLOCKED w/ clk_mezz_i
--//cycle through psec4a analog blocks, only handle sw triggers for now
proc_sample_hold : process(rst_i, clk_mezz_i, sw_trig_flag_int, sample_rdy_int)
begin
	if rst_i = '1' then
		sample_hold_int <= '0';
	elsif rising_edge(clk_mezz_i) and sw_trig_flag_int = '1' then
		sample_hold_int <= '1';
	elsif rising_edge(clk_mezz_i) and sample_rdy_int = '1' then
		sample_hold_int <= '0';
	end if;
end process;

--cycle through analog transfer blocks
proc_xfer_adr : process(rst_i, clk_mezz_i, sample_hold_int)
begin
	if rst_i = '1' then
		xfer_adr_o(2 downto 0) <= (others=>'0'); --//lower 3 bits in decoder = address bits for analog storage bank
		xfer_adr_o(3) <='1';  --//MSB in xfer_adr decoder acts as an 'enable'
	elsif rising_edge(clk_mezz_i) then
		--//simple sample and hold for now: if sw trigger asserted, stop sampling once xfer_adr reaches "111"
		if sample_hold_int = '1' and xfer_adr_o(2 downto 0) = "111" then
			xfer_adr_o(2 downto 0) <= "111";
			xfer_adr_o(3) <= '0';  --//disable xfer addr drivers
		else
			xfer_adr_o(2 downto 0) <= xfer_adr_o(2 downto 0) + 1;
			xfer_adr_o(3) <='1';
		end if;
	end if;
end process;
--//////////////////////
----------------------------------------------------------------------------------
--------------
--//first stab at psec4a digitization and readout control
--//
--// this is all done on clk_i
--//  nominally, would sync to clk_mezz_i, but due to eval board design contraints, only clk_i is on dedicated clock fabric
--------------

--//sync some control signals from the register interface:
RAMP_CNT_SYNC : for i in 0 to 15 generate
	xRAMP_CNT_SYNC : signal_sync
	port map(clkA=>clk_reg_i, clkB=>clk_i, SignalIn_clkA=> registers_i(79)(i), signalOut_clkB=> ramp_length_count_int(i));
end generate;

CONV_START_CNT_SYNC : for i in 0 to 15 generate
	CONV_START_CNT_SYNC : signal_sync
	port map(clkA=>clk_reg_i, clkB=>clk_i, SignalIn_clkA=> registers_i(78)(i), signalOut_clkB=> conv_start_count_int(i));
end generate;

proc_digz_rdout : process(rst_i, clk_i, sample_hold_int, rdout_counter_int)
variable dig_count : integer range 0 to 8 := 0;
begin
	if rst_i = '1' then
		sample_rdy_int <= '1';
		dig_count := 0;
		
		rdout_token_o <= '0';
		comp_sel_o <= "000";
		digz_latch_sel <= "00";
		digz_latch_transp <= '0';
		chan_sel_o <= "000";
		rdout_clk_en_int  <= '0';
		ramp_o <= '0'; 
		ring_osc_en_o <= '0';
		psec4a_digz_busy_int <= '0';
		psec4a_rdout_busy_int <= '0';
		clear_adc_o <= '0';
		clear_rdout_o <= '0';
		rdout_clk_en_int <= '0';
		latch_full <= "0000";

		conv_counter_int <= (others=>'0');
		
		psec4a_next_load_latch_state <= load_latch0_st;
		psec4a_next_empty_latch_state <= empty_latch2_st;
		psec4a_conversion_state <= idle_st;
		
	elsif rising_edge(clk_i) then
		case psec4a_conversion_state is
			
			when idle_st=>
				sample_rdy_int <= '0';
				dig_count := 0;
				
				chan_sel_o <= "000"
				rdout_token_o <= '0';
				comp_sel_o <= "111";
				digz_latch_sel <= "00";
				digz_latch_transp <= '0';
				ramp_o <= '0'; 
				ring_osc_en_o <= '0';
				clear_adc_o <= '1';
				psec4a_digz_busy_int <= '0';
				psec4a_rdout_busy_int <= '0';
				conv_counter_int <= (others=>'0');
				rdout_clk_en_int <= '0';
				clear_rdout_o <= '0';
				rdout_clk_en_int <= '0';
				
				psec4a_next_load_latch_state <= load_latch0_st;
				psec4a_next_empty_latch_state <= empty_latch2_st; --//empties in reverse order as load

				if sample_hold_int = '1' then
					psec4a_conversion_state <= start_st;
				else
					psec4a_conversion_state <= idle_st;
				end if;
			
		when start_st =>
			chan_sel_o <= "000"
			rdout_token_o <= '0';
			sample_rdy_int <= '0';
			comp_sel_o <= comp_sel_o + 1; --//go to next comparator
			digz_latch_sel <= "00";
			digz_latch_transp <= '0';
			ramp_o <= '1'; --//reset ramp
			ring_osc_en_o <= '0';
			clear_adc_o <= '1';  --//clear adc
			psec4a_digz_busy_int <= '1'; --//now busy
			
			psec4a_next_load_latch_state <= load_latch0_st; --//always have to start by loading latch 0
			psec4a_next_empty_latch_state <= empty_latch2_st;
			
			--//go to readout of all latches are full
			if latch_full = "1111" then
				conv_counter_int <= (others=>'0');
				psec4a_conversion_state <= readout_st;
		
			--// otherwise, wait and start another ramp-compare ADC conversion
			elsif conv_counter_int > conv_start_count_int then	
				conv_counter_int <= (others=>'0');
				psec4a_conversion_state <= ramp_st;
				
			else
				conv_counter_int <= conv_counter_int + 1;
				psec4a_conversion_state <= start_st;
			end if;
			
		when ramp_st =>
			clear_adc_o <= '0';
			psec4a_digz_busy_int <= '1';
			ring_osc_en_o <= '1';
			ramp_o <= '0';  --//ramp enable active low
			
			if conv_counter_int > ramp_length_count_int then
				conv_counter_int <= (others=>'0');
				dig_count := dig_count + 1; --//increment digitized block count
				psec4a_conversion_state <= psec4a_next_load_latch_state;			
			else
				conv_counter_int <= conv_counter_int + 1;
				psec4a_conversion_state <= ramp_st;
			end if;
			
		--//4 latches after each ADC bit (idea is to store data digitally to permit simultaneous digitizing & readout)
		--// --> so can digitize 4 of 8 blocks immediately, readout, and then digitize the other 4 (if reading out all 8 blocks)
		--//      to do this, we need to pass the first digitized block to the last (fourth) latch; the second block to to the third latch, and so on
		--//      the latches are arranged in serial, so data are required pass through all latches to get to readout stage.
		
		when load_latch0_st => 
			clear_adc_o <= '0';
			psec4a_digz_busy_int <= '1';
			ring_osc_en_o <= '0';
			ramp_o <= '0';  --//ramp stays high while latching data
			digz_latch_sel <= "00";	
			digz_latch_transp <= '1';
			
			latch_full(0) <= '1';
			
			psec4a_conversion_state <= next_load_latch_st;
			psec4a_next_load_latch_state <= load_latch1_st;

		when load_latch1_st => 
			clear_adc_o <= '0';
			psec4a_digz_busy_int <= '1';
			ring_osc_en_o <= '0';
			ramp_o <= '0';  --//ramp stays high while latching data
			digz_latch_sel <= "01";	
			digz_latch_transp <= '1';
			
			latch_full(0) <= '0';
			latch_full(1) <= '1';

			psec4a_conversion_state <= next_load_latch_st;
			psec4a_next_load_latch_state <= load_latch2_st;	
	
		when load_latch2_st => 
			clear_adc_o <= '0';
			psec4a_digz_busy_int <= '1';
			ring_osc_en_o <= '0';
			ramp_o <= '0';  --//ramp stays high while latching data
			digz_latch_sel <= "10";	
			digz_latch_transp <= '1';
			
			latch_full(1) <= '0';
			latch_full(2) <= '1';

			psec4a_conversion_state <= next_load_latch_st;
			psec4a_next_load_latch_state <= load_latch3_st;	
			
		when load_latch3_st => 
			clear_adc_o <= '0';
			psec4a_digz_busy_int <= '1';
			ring_osc_en_o <= '0';
			ramp_o <= '0';  --//ramp stays high while latching data
			digz_latch_sel <= "11";	
			digz_latch_transp <= '1';
			
			latch_full(2) <= '0';
			latch_full(3) <= '1';
			
			psec4a_conversion_state <= start_st;
			psec4a_next_load_latch_state <= load_latch0_st;
			
		when next_load_latch_st =>
			digz_latch_transp <= '0';
			
			--//if next latch is full, go back to start
			if latch_full(to_integer(unsigned(digz_latch_sel+1))) = '1' then
				psec4a_conversion_state <= start_st;
				
			--//otherwise, load the next latch
			else
				psec4a_conversion_state <= psec4a_next_load_latch_state;
			end if;
			
		when readout_channel_update_st => 
			psec4a_digz_busy_int <= '0';
			psec4a_rdout_busy_int <= '1';
			
			clear_adc_o <= '0'; 
			ring_osc_en_o <= '0';
			ramp_o <= '0';
			
			clear_rdout_o <= '1'; --//clear readout registers
			rdout_token_o <= '0';
			rdout_clk_en_int <= '0';
			
			conv_counter_int <= (others=>'0');
			latch_full(3) <= '0';
			
			if chan_sel_o = "111" then
				chan_sel_o <= "000";
				if latch_full(0) = '1' or latch_full(1) = '1' or latch_full(2) = '1' then
					psec4a_conversion_state <= next_empty_latch_st;
				
				--//digitize and readout the other blocks
				elsif dig_count < 7 then
					psec4a_conversion_state <= start_st;
				
				--//otherwise done w/ complete readout
				else
					psec4a_conversion_state <= idle_st; --//DONE
			else
				chan_sel_o <= chan_sel_o + 1;
				psec4a_conversion_state <= readout_st;
			end if;
				
		--//readout
		when readout_st =>
			psec4a_digz_busy_int <= '0';
			psec4a_rdout_busy_int <= '1';
			
			clear_adc_o <= '0'; 
			ring_osc_en_o <= '0';
			ramp_o <= '0';
			
			--//done w/ readout of channel
			if conv_counter_int = rdout_clk_count_int + 2 then
				clear_rdout_o <= '0';
				rdout_token_o <= '0';
				rdout_clk_en_int <= '0';
				conv_counter_int <= (others=>'0');
				psec4a_conversion_state <= readout_channel_update_st;
			
			--//second clock cycle, toggle read token
			elsif conv_counter_int = 1 then
				clear_rdout_o <= '0';
				rdout_token_o <= '1';
				rdout_clk_en_int <= '1';
				conv_counter_int <= conv_counter_int + 1;
				psec4a_conversion_state <= readout_st;	
				
			--//first clock cycle, keep readout clear, but enable clock
			elsif conv_counter_int = 0 then
				clear_rdout_o <= '1';
				rdout_token_o <= '0';
				rdout_clk_en_int <= '1';
				conv_counter_int <= conv_counter_int + 1;
				psec4a_conversion_state <= readout_st;	
				
			--//keep readout clock enabled
			else
				clear_rdout_o <= '0';
				rdout_token_o <= '0';
				rdout_clk_en_int <= '1';
				conv_counter_int <= conv_counter_int + 1;
				psec4a_conversion_state <= readout_st;
			end if;
			
		when empty_latch2_st => 
			psec4a_digz_busy_int <= '0';
			psec4a_rdout_busy_int <= '1';
			
			clear_adc_o <= '0'; 
			ring_osc_en_o <= '0';
			ramp_o <= '0';
			
			clear_rdout_o <= '0';
			rdout_token_o <= '0';
			rdout_clk_en_int <= '0';
			
			--//toggle the 4th latch --> copy values in the third latch to the fourth latch
			digz_latch_sel <= "11";	
			digz_latch_transp <= '1';
			latch_full(2) <= '0';
			latch_full(3) <= '1';
			
			if latch_full(1) = '1' then
				psec4a_next_empty_latch_state <= empty_latch1_st;
			elsif latch_full(0) = '1' then
				psec4a_next_empty_latch_state <= empty_latch0_st;
			else
				psec4a_next_empty_latch_state <= empty_latch2_st;
			end if;
			--//goto readout
			psec4a_conversion_state <= readout_st;
			
		when empty_latch1_st => 
			psec4a_digz_busy_int <= '0';
			psec4a_rdout_busy_int <= '1';
			
			clear_adc_o <= '0'; 
			ring_osc_en_o <= '0';
			ramp_o <= '0';
			
			clear_rdout_o <= '0';
			rdout_token_o <= '0';
			rdout_clk_en_int <= '0';
			
			--//toggle the 3rd latch --> copy values in the second latch to the third latch
			digz_latch_sel <= "10";	
			digz_latch_transp <= '1';
			latch_full(1) <= '0';
			latch_full(2) <= '1';
			
			psec4a_conversion_state <= empty_latch2_st;
			
		when empty_latch0_st => 
			psec4a_digz_busy_int <= '0';
			psec4a_rdout_busy_int <= '1';
			
			clear_adc_o <= '0'; 
			ring_osc_en_o <= '0';
			ramp_o <= '0';
			
			clear_rdout_o <= '0';
			rdout_token_o <= '0';
			rdout_clk_en_int <= '0';
			
			--//toggle the 2nd latch --> copy values in the first latch to the second latch
			digz_latch_sel <= "01";	
			digz_latch_transp <= '1';
			latch_full(0) <= '0';
			latch_full(1) <= '1';
			
			psec4a_conversion_state <= empty_latch1_st;
			
		end case;
	end if;
end process;
		
	
end rtl;
	 