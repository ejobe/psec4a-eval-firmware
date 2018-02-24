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
	clk_i				: 	in 	std_logic;  --//clock for register stuff
	clk_mezz_i		:	in		std_logic;  --//clock from mezzanine board on which psec4a is using for sampling
	registers_i		:	in		register_array_type;
	
	dll_start_o		:	out	std_logic; --//psec4a dll reset/enable
	xfer_adr_o		:	inout	std_logic_vector(3 downto 0); --//psec4a analog write address
	ramp_o			:	out	std_logic; --//psec4a ramp toggle
	ring_osc_en_o	:	out	std_logic; --//psec4a ring oscillator enable
	comp_sel_o		:	inout	std_logic_vector(2 downto 0); --//psec4a comparator select
	latchsel_o		:	inout	std_logic_vector(1 downto 0); --//psec4a select ADC latchsel_o
	latch_transp_o	:	out	std_logic; --//enable latch transparency
	clear_adc_o		:	out	std_logic; --//psec4a clear ADC counters
	rdout_clk_o		:  out	std_logic; --//psec4a readout clock
	chan_sel_o		:	out	std_logic_vector(2 downto 0); --//psec4a readout channel select
	
	psec4a_dat_i	:	in		std_logic_vector(10 downto 0); --//psec4a data bus
	psec4a_trig_i	:	in		std_logic_vector(7 downto 0));

end psec4a_core;

architecture rtl of psec4a_core is

signal sw_trig_flag_int : std_logic; --//sw trigger flag transferred to clk_mezz_i
signal sample_hold_int : std_logic;  --//signal high to hold psec4a sampling
signal sample_rdy_int : std_logic; --//flag to restart psec4a sampling

signal psec4a_digz_busy_int : std_logic;  --//psec4a is digitizing
signal psec4a_rdout_busy_int : std_logic; --//psec4a is reading out data

signal conv_counter_int : std_logic_vector(15 downto 0);
signal conv_start_count_int : std_logic_vector(15 downto 0) := x"0004";
signal ramp_length_count_int : std_logic_vector(15 downto 0);

signal rdout_counter_int : std_logic_vector(15 downto 0);

type psec4a_conversion_state_type is (idle_st, start_st, digitize_st, latch_st, wait_for_rdout_st);
signal psec4a_conversion_state : psec4a_conversion_state_type;

type psec4a_rdout_state_type is (idle_st, start_st, digitize_st, latch_st, wait_for_rdout_st);
signal psec4a_rdout_state : psec4a_conversion_state_type;

component flag_sync is
port(
	clkA			: in	std_logic;
	clkB			: in	std_logic;
	in_clkA		: in	std_logic;
	busy_clkA	: out	std_logic;
	out_clkB		: out	std_logic);
end component;
	
begin

xSW_TRIG_SYNC : flag_sync
port map(clkA => clk_i, clkB=> clk_mezz_i, in_clkA=>registers_i(64)(0),
			out_clkB => sw_trig_flag_int);
	
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
--------------
--//first stab at psec4a digitization and readout control
--------------
proc_digz_rdout : process(rst_i, clk_mezz_i, sample_hold_int, latchsel_o)
variable dig_count : integer range 0 to 8 := 0;
begin
	if rst_i = '1' then
		sample_rdy_int <= '1';
		dig_count := 0;
		
		comp_sel_o <= "000";
		latchsel_o <= "00";
		latch_transp_o <= '0';
		chan_sel_o <= "000";
		rdout_clk_o <= '0';
		ramp_o <= '1'; --//active low, I think
		ring_osc_en_o <= '0';
		psec4a_digz_busy_int <= '0';
		clear_adc_o <= '0';
		conv_counter_int <= (others=>'0');
		psec4a_conversion_state <= idle_st;
		
	elsif rising_edge(clk_mezz_i) then
		case psec4a_conversion_state is
			
			when idle_st=>
				sample_rdy_int <= '0';
				comp_sel_o <= "111";
				latchsel_o <= "00";
				latch_transp_o <= '0';
				ramp_o <= '1'; 
				ring_osc_en_o <= '0';
				clear_adc_o <= '1';
				dig_count := 0;
				psec4a_digz_busy_int <= '0';
		
				if sample_hold_int = '1' then
					--//counter here allows some wait time before starting digitization (i.e. leakage studies)
					if conv_counter_int >= conv_start_count_int then
						conv_counter_int <= (others=>'0');
						psec4a_conversion_state <= start_st;
					else
						conv_counter_int <= conv_counter_int + 1;
					end if;
				
				else
					conv_counter_int <= (others=>'0');
					psec4a_conversion_state <= idle_st;
				end if;
			
		when start_st =>
			sample_rdy_int <= '0';
			comp_sel_o <= comp_sel_o + 1; --//go to next comparator
			latchsel_o <= "11";
			latch_transp_o <= '0';
			ramp_o <= '1'; 
			ring_osc_en_o <= '0';
			clear_adc_o <= '1'; 
			psec4a_digz_busy_int <= '1'; --//now busy
			psec4a_conversion_state <= digitize_st;			
				
		when digitize_st =>
			clear_adc_o <= '0';
			psec4a_digz_busy_int <= '1';
			ring_osc_en_o <= '1';
			ramp_o <= '0';  --//ramp enable active low
			if conv_counter_int > ramp_length_count_int then
				conv_counter_int <= (others=>'0');
				dig_count := dig_count + 1; --//increment digitized block count
				psec4a_conversion_state <= latch_st;			
			else
				conv_counter_int <= conv_counter_int + 1;
			end if;
			
		when latch_st => 
			clear_adc_o <= '0';
			psec4a_digz_busy_int <= '1';
			ring_osc_en_o <= '0';
			ramp_o <= '0';  --//ramp stays high while latching data
						
			--//4 latches after each ADC bit (idea is to store data digitally to permit simultaneous digitizing & readout)
			--// --> so can digitize 4 of 8 blocks immediately, readout, and then digitize the other 4 (if reading out all 8 blocks)
			--//      to do this, we need to pass the first digitized block to the last (fourth) latch; the second block to to the third latch, and so on
			--//      the latches are arranged in serial, so data are required pass through all latches to get to readout stage.

			--//every two clk cycles, increment the latch addr
			if conv_counter_int(0) = '0' then
				latchsel_o <= latchsel_o + 1;
			else
				latchsel_o <= latchsel_o;
			end if;
			
			if latchsel_o = "00" and dig_count mod 4 = 1 and conv_counter_int > 2 then
				conv_counter_int <= (others=>'0');
				latch_transp_o <= '0';
				psec4a_conversion_state <= start_st;
			elsif latchsel_o = "11" and dig_count mod 4 = 2 then
				conv_counter_int <= (others=>'0');
				latch_transp_o <= '0';
				psec4a_conversion_state <= start_st;
			elsif latchsel_o = "10" and dig_count mod 4 = 3 then
				conv_counter_int <= (others=>'0');
				latch_transp_o <= '0';
				psec4a_conversion_state <= start_st;
			elsif latchsel_o = "01" and dig_count mod 4 = 0 then
				conv_counter_int <= (others=>'0');
				latch_transp_o <= '0';
				psec4a_conversion_state <= wait_for_rdout_st; --//filled the latches! now readout
			else
				conv_counter_int <= conv_counter_int + 1;
				latch_transp_o <= conv_counter_int(0); --//make latch transparent when counter LSB=1
				psec4a_conversion_state <= latch_st;
			end if;
			
		when wait_for_rdout_st =>
			psec4a_digz_busy_int <= '0';
			clear_adc_o <= '0';
			ring_osc_en_o <= '0';
			psec4a_conversion_state <= idle_st;
			
		end case;
	end if;
end process;
		
	
end rtl;
	 