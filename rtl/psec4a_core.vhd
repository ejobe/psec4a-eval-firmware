---------------------------------------------------------------------------------
--
-- PROJECT:      psec4a eval
-- FILE:         psec4a_core.vhd
-- AUTHOR:       e.oberla
-- EMAIL         eric.oberla@gmail.com
-- DATE:         2/2018...
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
	latch_sel_o		:	out	std_logic_vector(3 downto 0); --//psec4a 'latch' decoder
	rdout_clk_o		:  out	std_logic; --//psec4a readout clock
	chan_sel_o		:	buffer	std_logic_vector(2 downto 0)); --//psec4a readout channel select
	
	--psec4a_trig_i	:	in		std_logic_vector(5 downto 0)); --//(whoops, only 6/8 trig lines routed on the board!)

end psec4a_core;

architecture rtl of psec4a_core is

signal sw_trig_flag_int : std_logic; --//sw trigger flag transferred to clk_mezz_i
signal sample_hold_int : std_logic;  --//signal high to hold psec4a sampling
signal sample_rdy_int : std_logic; --//flag to restart psec4a sampling

signal conv_counter_int : std_logic_vector(15 downto 0) := (others=>'0');
signal conv_start_count_int : std_logic_vector(15 downto 0);
signal rdout_clk_count_int : std_logic_vector(15 downto 0) := x"0084"; --//132 clk cycles per readout
signal ramp_length_count_int : std_logic_vector(15 downto 0);

signal rdout_clk_en_int : std_logic;
signal rdout_clear_int : std_logic;
signal rdout_token_int : std_logic;
signal adc_clear_int : std_logic;

--//ADC counter latches can be controlled by ADC or readout
signal digz_latch_sel	 : std_logic_vector(1 downto 0);	
signal digz_latch_transp : std_logic;
signal latch_full : std_logic_vector(3 downto 0) := (others=>'0');

--//psec4a A/D conversion fsm:
--type psec4a_conversion_state_type is (idle_st, start_st, digitize_st, latch_st, wait_for_rdout_st);
--signal psec4a_conversion_state : psec4a_conversion_state_type;
type psec4a_conversion_state_type is (idle_st, start_st, ramp_st, load_latch0_st, load_latch1_st, load_latch2_st, load_latch3_st, 
												next_load_latch_st, readout_st, empty_latch0_st, empty_latch1_st, empty_latch2_st, 
												readout_channel_update_st, done_st);
												
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

rdout_clk_o <= clk_i and rdout_clk_en_int;

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

proc_digz_rdout : process(rst_i, clk_i, sample_hold_int)
variable dig_count : integer range 0 to 8 := 0;
begin
	if rst_i = '1' then
		
		sample_rdy_int <= '0'; --//flag needs to goes high when ready to start sampling again
				
		--//adc-latch signals: used for both adc and readout
		digz_latch_sel <= "00";
		digz_latch_transp <= '0';
		latch_full <= "0000";
		--//adc-specific signals
		dig_count := 0; --//number of ADC cycles (max 8)
		comp_sel_o <= "000";
		ramp_o <= '0'; 
		ring_osc_en_o <= '0';
		adc_clear_int <= '1';
		--//counter for various use
		conv_counter_int <= (others=>'0');	
		--//readout-specific signals
		rdout_clear_int <= '0';    --//clear signal for readout shift register
		rdout_clk_en_int <= '0'; --//gate for readout clock sent to psec4a
		chan_sel_o <= "000";      --//psec4a channel select decoder
		rdout_token_int <= '0';    --//readout start signal - needs to be high for a single clock cycle to initiate
		
		psec4a_next_load_latch_state <= load_latch0_st;
		psec4a_next_empty_latch_state <= empty_latch2_st;
		psec4a_conversion_state <= idle_st;
		
	elsif rising_edge(clk_i) then
		case psec4a_conversion_state is
			
		when idle_st=>
			sample_rdy_int <= '0'; --//flag needs to goes high when ready to start sampling again
			
			--//adc-latch signals: used for both adc and readout
			digz_latch_sel <= "00";
			digz_latch_transp <= '0';
			latch_full <= "0000";	
			--//adc-specific signals
			dig_count := 0; --//number of ADC cycles (max 8)
			comp_sel_o <= "111";
			ramp_o <= '0'; 
			ring_osc_en_o <= '0';
			adc_clear_int <= '0';
			--//counter for various use
			conv_counter_int <= (others=>'0');
			--//readout-specific signals
			rdout_clear_int <= '0';
			rdout_clk_en_int <= '0';
			chan_sel_o <= "000";
			rdout_token_int <= '0';
			
			psec4a_next_load_latch_state <= load_latch0_st;
			psec4a_next_empty_latch_state <= empty_latch2_st; --//empties in reverse order as load

			if sample_hold_int = '1' then
				psec4a_conversion_state <= start_st;
			else
				psec4a_conversion_state <= idle_st;
			end if;
			
		when start_st =>
			sample_rdy_int <= '0'; --//flag needs to goes high when ready to start sampling again
			--//readout-specific signals:
			rdout_clear_int <= '0';
			rdout_clk_en_int <= '0';
			chan_sel_o <= "000";
			rdout_token_int <= '0';
			--//adc-latch signals: used for both adc and readout
			digz_latch_sel <= "00";
			digz_latch_transp <= '0';
			latch_full <= latch_full;
			--//adc-specific signals
			ramp_o <= '1'; --//clear ramp in preperation for conversion
			ring_osc_en_o <= '0';
			adc_clear_int <= '1'; --//clear adc in prep for conversion
			
			psec4a_next_load_latch_state <= load_latch0_st; --//always have to start by loading latch 0
			psec4a_next_empty_latch_state <= empty_latch2_st;
			
			--//go to readout of all latches are full
			if latch_full = "1111" then
				conv_counter_int <= (others=>'0');
				psec4a_conversion_state <= readout_st;
		
			--// otherwise, wait and start another ramp-compare ADC conversion
			elsif conv_counter_int > conv_start_count_int then	
				
				comp_sel_o <= comp_sel_o + 1; --//go to next comparator
				
				conv_counter_int <= (others=>'0');
				psec4a_conversion_state <= ramp_st;
				
			else
				conv_counter_int <= conv_counter_int + 1;
				psec4a_conversion_state <= start_st;
			end if;
			
		--------------------------------------------------------
		-- ADC control
		--------------------------------------------------------	
		when ramp_st =>
			sample_rdy_int <= '0'; --//flag needs to goes high when ready to start sampling again
			--//readout-specific signals:
			rdout_clear_int <= '0';
			rdout_clk_en_int <= '0';
			chan_sel_o <= "000";
			rdout_token_int <= '0';
			--//adc-latch signals: used for both adc and readout
			digz_latch_sel <= "00";
			digz_latch_transp <= '0';
			latch_full <= latch_full;
			
			if conv_counter_int > ramp_length_count_int + 1 then
				ramp_o <= '0'; --// ramp charged up
				ring_osc_en_o <= '0'; --//ro off
				adc_clear_int <= '0'; --//release adc clear
				conv_counter_int <= (others=>'0');
				dig_count := dig_count + 1; --//increment digitized block count
				psec4a_conversion_state <= psec4a_next_load_latch_state;		
			elsif conv_counter_int = 0 then			
				ramp_o <= '0'; --//release ramp clear, ramp cap charging up
				ring_osc_en_o <= '0'; --//keep ro off
				adc_clear_int <= '0'; --//release adc clear
				conv_counter_int <= conv_counter_int + 1;
				psec4a_conversion_state <= ramp_st;
			else
				ramp_o <= '0'; --// ramp cap charging up
				ring_osc_en_o <= '1'; --//enable ring oscillator buffer drivers
				adc_clear_int <= '0'; --//release adc clear
				conv_counter_int <= conv_counter_int + 1;
				psec4a_conversion_state <= ramp_st;
			end if;
			
		--//4 latches after each ADC bit (idea is to store data digitally to permit simultaneous digitizing & readout)
		--// --> so can digitize 4 of 8 blocks immediately, readout, and then digitize the other 4 (if reading out all 8 blocks)
		--//      to do this, we need to pass the first digitized block to the last (fourth) latch; the second block to to the third latch, and so on
		--//      the latches are arranged in serial, so data are required pass through all latches to get to readout stage.
		
		when load_latch0_st => 
			sample_rdy_int <= '0'; --//flag needs to goes high when ready to start sampling again
			--//readout-specific signals:
			rdout_clear_int <= '0';
			rdout_clk_en_int <= '0';
			chan_sel_o <= "000";
			rdout_token_int <= '0';
			--//adc-specific signals
			ramp_o <= '0';  --//ramp stays high while latching data
			ring_osc_en_o <= '0'; 
			adc_clear_int <= '0'; 

			conv_counter_int <= (others=>'0');
			
			--//modify latch-specific signals:
			digz_latch_sel <= "00";	
			digz_latch_transp <= '1';
			latch_full(0) <= '1';
			
			psec4a_conversion_state <= next_load_latch_st;
			psec4a_next_load_latch_state <= load_latch1_st;

		when load_latch1_st => 
			sample_rdy_int <= '0'; --//flag needs to goes high when ready to start sampling again
			--//readout-specific signals:
			rdout_clear_int <= '0';
			rdout_clk_en_int <= '0';
			chan_sel_o <= "000";
			rdout_token_int <= '0';
			--//adc-specific signals
			ramp_o <= '0';  --//ramp stays high while latching data
			ring_osc_en_o <= '0'; 
			adc_clear_int <= '0'; 

			conv_counter_int <= (others=>'0');
			
			--//modify latch-specific signals:
			digz_latch_sel <= "01";	
			digz_latch_transp <= '1';
			latch_full(0) <= '0';
			latch_full(1) <= '1';

			psec4a_conversion_state <= next_load_latch_st;
			psec4a_next_load_latch_state <= load_latch2_st;	
	
		when load_latch2_st => 
			sample_rdy_int <= '0'; --//flag needs to goes high when ready to start sampling again
			--//readout-specific signals:
			rdout_clear_int <= '0';
			rdout_clk_en_int <= '0';
			chan_sel_o <= "000";
			rdout_token_int <= '0';
			--//adc-specific signals
			ramp_o <= '0';  --//ramp stays high while latching data
			ring_osc_en_o <= '0'; 
			adc_clear_int <= '0'; 

			conv_counter_int <= (others=>'0');
			
			--//modify latch-specific signals:
			digz_latch_sel <= "10";	
			digz_latch_transp <= '1';
			latch_full(1) <= '0';
			latch_full(2) <= '1';

			psec4a_conversion_state <= next_load_latch_st;
			psec4a_next_load_latch_state <= load_latch3_st;	
			
		when load_latch3_st => 
			sample_rdy_int <= '0'; --//flag needs to goes high when ready to start sampling again
			--//readout-specific signals:
			rdout_clear_int <= '0';
			rdout_clk_en_int <= '0';
			chan_sel_o <= "000";
			rdout_token_int <= '0';
			--//adc-specific signals
			ramp_o <= '0';  --//ramp stays high while latching data
			ring_osc_en_o <= '0'; 
			adc_clear_int <= '0'; 

			conv_counter_int <= (others=>'0');
			
			--//modify latch-specific signals:
			digz_latch_sel <= "11";	
			digz_latch_transp <= '1';
			latch_full(2) <= '0';
			latch_full(3) <= '1';
			
			psec4a_conversion_state <= start_st;
			psec4a_next_load_latch_state <= load_latch0_st;
			
		when next_load_latch_st =>
			sample_rdy_int <= '0'; --//flag needs to goes high when ready to start sampling again
			--//readout-specific signals:
			rdout_clear_int <= '0';
			rdout_clk_en_int <= '0';
			chan_sel_o <= "000";
			rdout_token_int <= '0';
			--//adc-specific signals
			ramp_o <= '0';  --//ramp stays high while latching data
			ring_osc_en_o <= '0'; 
			adc_clear_int <= '0'; 

			conv_counter_int <= (others=>'0');
			
			--//set latch transparent flag to zero for a clk cycle:
			digz_latch_transp <= '0';
			digz_latch_sel <= digz_latch_sel;
			latch_full <= latch_full;
			
			--//if next latch is full, go back to start
			if latch_full(to_integer(unsigned(digz_latch_sel+1))) = '1' then
				psec4a_conversion_state <= start_st;
				
			--//otherwise, load the next latch
			else
				psec4a_conversion_state <= psec4a_next_load_latch_state;
			end if;
			
		--------------------------------------------------------
		-- readout control
		--------------------------------------------------------
		when readout_channel_update_st => 
			sample_rdy_int <= '0'; --//flag needs to goes high when ready to start sampling again
			
			--//adc-specific signals
			ramp_o <= '0';  
			ring_osc_en_o <= '0'; 
			adc_clear_int <= '0'; 
			
			--//readout-specific signals:
			rdout_clear_int <= '1'; --//clear readout registers
			rdout_clk_en_int <= '0';
			rdout_token_int <= '0';
			
			conv_counter_int <= (others=>'0');
			
			--//latch signals
			digz_latch_transp <= '0';
			latch_full(3) <= '0'; --//last latch now 'empty', since readout just performed
			
			if chan_sel_o = "111" then
				chan_sel_o <= "000";
				if latch_full(0) = '1' or latch_full(1) = '1' or latch_full(2) = '1' then
					psec4a_conversion_state <= psec4a_next_empty_latch_state;
				
				--//digitize and readout the other blocks
				elsif dig_count < 7 then
					psec4a_conversion_state <= start_st;
				
				--//otherwise done w/ complete readout
				else
					psec4a_conversion_state <= done_st; --//DONE
				end if;
			else
				chan_sel_o <= chan_sel_o + 1;
				psec4a_conversion_state <= readout_st;
			end if;
				
		--//readout
		when readout_st =>
			sample_rdy_int <= '0'; --//flag needs to goes high when ready to start sampling again
						
			--//adc-specific signals
			adc_clear_int <= '0'; 
			ring_osc_en_o <= '0';
			ramp_o <= '0';
			
			--//latch signals
			digz_latch_transp <= '0';
			digz_latch_sel <= digz_latch_sel;
			latch_full <= latch_full;
			
			--//done w/ readout of channel
			if conv_counter_int = rdout_clk_count_int + 2 then
				rdout_clear_int <= '0';
				rdout_token_int <= '0';
				rdout_clk_en_int <= '0';
				conv_counter_int <= (others=>'0');
				psec4a_conversion_state <= readout_channel_update_st;
			
			--//second clock cycle, toggle read token
			elsif conv_counter_int = 1 then
				rdout_clear_int <= '0';
				rdout_token_int <= '1';
				rdout_clk_en_int <= '1';
				conv_counter_int <= conv_counter_int + 1;
				psec4a_conversion_state <= readout_st;	
				
			--//first clock cycle, keep readout clear, enable clock
			elsif conv_counter_int = 0 then
				rdout_clear_int <= '1';
				rdout_token_int <= '0';
				rdout_clk_en_int <= '1';
				conv_counter_int <= conv_counter_int + 1;
				psec4a_conversion_state <= readout_st;	
				
			--//keep readout clock enabled
			else
				rdout_clear_int <= '0';
				rdout_token_int <= '0';
				rdout_clk_en_int <= '1';
				conv_counter_int <= conv_counter_int + 1;
				psec4a_conversion_state <= readout_st;
			end if;
			
		when empty_latch2_st => 
			sample_rdy_int <= '0'; --//flag needs to goes high when ready to start sampling again
						
			--//adc-specific signals
			adc_clear_int <= '0'; 
			ring_osc_en_o <= '0';
			ramp_o <= '0';
			
			--//readout-specific signals: keep clear and token low, in order for latch_transparent to toggle decoder
			rdout_clear_int <= '0'; 
			rdout_clk_en_int <= '0';
			rdout_token_int <= '0';
			
			--//latch signals
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
			sample_rdy_int <= '0'; --//flag needs to goes high when ready to start sampling again
						
			--//adc-specific signals
			adc_clear_int <= '0'; 
			ring_osc_en_o <= '0';
			ramp_o <= '0';
			
			--//readout-specific signals: keep clear and token low, in order for latch_transparent to toggle decoder
			rdout_clear_int <= '0'; 
			rdout_clk_en_int <= '0';
			rdout_token_int <= '0';
			
			--//latch signals
			--//toggle the 3rd latch --> copy values in the second latch to the third latch
			digz_latch_sel <= "10";	
			digz_latch_transp <= '1';
			latch_full(1) <= '0';
			latch_full(2) <= '1';
			
			psec4a_conversion_state <= empty_latch2_st;
			
		when empty_latch0_st => 
			sample_rdy_int <= '0'; --//flag needs to goes high when ready to start sampling again
						
			--//adc-specific signals
			adc_clear_int <= '0'; 
			ring_osc_en_o <= '0';
			ramp_o <= '0';
			
			--//readout-specific signals: keep clear and token low, in order for latch_transparent to toggle decoder
			rdout_clear_int <= '0'; 
			rdout_clk_en_int <= '0';
			rdout_token_int <= '0';
			
			--//latch signals
			--//toggle the 2nd latch --> copy values in the first latch to the second latch
			digz_latch_sel <= "01";	
			digz_latch_transp <= '1';
			latch_full(0) <= '0';
			latch_full(1) <= '1';
			
			psec4a_conversion_state <= empty_latch1_st;
		
		---------------------------------
		-- DONE w/ event conversion and readout
		---------------------------------
		--//set sample_rdy_int flag to high, go back to idle_st
		when done_st =>
			sample_rdy_int <= '1'; --//flag needs to goes high when ready to start sampling again
			
			--//adc-latch signals: used for both adc and readout
			digz_latch_sel <= "00";
			digz_latch_transp <= '0';
			latch_full <= "0000";	
			--//adc-specific signals
			dig_count := 0; --//number of ADC cycles (max 8)
			comp_sel_o <= "111";
			ramp_o <= '0'; 
			ring_osc_en_o <= '0';
			adc_clear_int <= '0';
			--//counter for various use
			conv_counter_int <= (others=>'0');
			--//readout-specific signals
			rdout_clear_int <= '0';
			rdout_clk_en_int <= '0';
			chan_sel_o <= "000";
			rdout_token_int <= '0';
			
			psec4a_conversion_state <= idle_st;
			
		end case;
	end if;
end process;

------------------------------------------------------------------------
------------------------------------
--psec4a `latch decoder': bits 2 downto 0
-- 0  adc bit latch sel 0
-- 1  adc bit latch sel 1
-- 2  adc bit latch sel 2
-- 3  adc bit latch sel 3
-- 4  adc counter clear
-- 5  read shift register clear
-- 6  clear serial shift register and latches
-- 7  read token in
--EN  bit 3 ['0'=all decoded outputs at 0; '1'=selected output active]
------------------------------------
process(rst_i, digz_latch_transp, digz_latch_sel, adc_clear_int, 
         rdout_clear_int, rdout_token_int)
begin
	--apply reset on serial interfae on rst_i only
	if rst_i = '1' then
		latch_sel_o <= "1110";
	
	elsif digz_latch_transp = '1' then
		case digz_latch_sel is
			when "00" => latch_sel_o <= "1000";
			when "01" => latch_sel_o <= "1001";
			when "10" => latch_sel_o <= "1010";
			when "11" => latch_sel_o <= "1011";
		end case;
	
	elsif adc_clear_int = '1' then
		latch_sel_o <= "1100";
	
	elsif rdout_clear_int = '1' then
		latch_sel_o <= "1101";		
	
	elsif rdout_token_int= '1' then
		latch_sel_o <= "1111";	
	
	else
		latch_sel_o <= "0000";
	end if;
end process;
-----
------------------------------------------------------------------------		
end rtl;