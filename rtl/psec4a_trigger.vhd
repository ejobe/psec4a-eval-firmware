---------------------------------------------------------------------------------
--
-- PROJECT:      psec4a eval
-- FILE:         psec4a_trigger.vhd
-- AUTHOR:       e.oberla
-- EMAIL         eric.oberla@gmail.com
-- DATE:         7/2018...
--
-- DESCRIPTION:  handles psec4a self-trigger
--
---------------------------------------------------------------------------------
library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.defs.all;

--//self trigger bits from psec4a are registered on-chip using the sampling clock, clk_mezz_i on the psec4a eval system
--//trigger bits are self-reset on-chip after 2 sample clock cycles
--//
--//in this code block, we have the ability to count triggers, generate a board-level trigger for acquisition, etc..
--//
--//register 75 holds the trigger mode; register 76 holds the trigger mask

entity psec4a_trigger is
port(
	rst_i				:	in		std_logic;
	clk_reg_i		: 	in 	std_logic;  --//clock for register stuff (and for trigger scalers)
	clk_mezz_i		:	in		std_logic;  --//clock from mezzanine board which psec4a is using for sampling
	registers_i		:	in		register_array_type;

	trigger_i		:	in		std_logic_vector(7 downto 0); --//psec4a trigger bits
	clear_trigger_i:	in		std_logic; --//clear firmware trigger bits
	
	trigger_o  		:	out	std_logic;
	trigger_patt_o	:	out	std_logic_vector(7 downto 0); --//trig pattern
	trigger_scaler_o : out	std_logic_vector(7 downto 0)); 
	
end psec4a_trigger;
--
architecture rtl of psec4a_trigger is

signal trigger_meta: std_logic_vector(7 downto 0); --//latched trigger registers
signal trigger_reg: std_logic_vector(7 downto 0);

type trigger_oneshot_reg_type is array(7 downto 0) of std_logic_vector(1 downto 0); 
signal trigger_oneshot_reg: trigger_oneshot_reg_type; --//for scaler counting

signal trigger_or: std_logic; --//OR of channel triggers + mask
signal trigger_and: std_logic; --//AND of channel triggers + mask
signal trigger_count: std_logic; --//SUM of channel triggers + mask
--signal trigger_fast: std_logic; --//low latency trigger, fires when first trigger bit goes high

signal internal_clear_trigger : std_logic;
signal internal_trig_mask: std_logic_vector(7 downto 0);

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
--
begin
--
TRIG_BIT_SYNC : for i in 0 to 7 generate
	xTRIG_BIT_SYNC : flag_sync
	port map(clkA => clk_mezz_i, clkB=> clk_reg_i, in_clkA=> ( (not trigger_oneshot_reg(i)(1)) and trigger_oneshot_reg(i)(0) ),
				out_clkB => trigger_scaler_o(i));
	end generate;
--
proc_trig_oneshot : process(clk_mezz_i)
begin
for i in 0 to 7 loop
	if rising_edge(clk_mezz_i) then
		trigger_oneshot_reg(i)(1) <= trigger_oneshot_reg(i)(0);
		trigger_oneshot_reg(i)(0) <= trigger_i(i);
	end if;
end loop;
end process;

TRIG_MASK_SYNC : for i in 0 to 7 generate
	xTRIG_MASK_SYNC : signal_sync
		port map(clkA=>clk_reg_i, clkB=>clk_mezz_i, SignalIn_clkA=> registers_i(76)(i), signalOut_clkB=> internal_trig_mask(i));
	end generate;

proc_get_trig : process(rst_i, trigger_i, clear_trigger_i, clk_mezz_i)
begin
for i in 0 to 7 loop
	if rst_i = '1' then
		trigger_meta(i) <= '0';
		trigger_reg(i) <= '0';
		
	elsif rising_edge(clk_mezz_i) and trigger_i(i) = '1' then
		trigger_reg(i) <= trigger_meta(i);
		trigger_meta(i) <= '1' and internal_trig_mask(i);
	
	elsif rising_edge(clk_mezz_i) and (clear_trigger_i = '1' or internal_clear_trigger = '1') then
		trigger_meta(i) <= '0';
		trigger_reg(i) <= '0';
		
	end if;
end loop;
end process;

proc_assign_trig : process(rst_i, trigger_i, clear_trigger_i, clk_mezz_i)
begin
	if rst_i = '1' then
		trigger_o <= '0';
		internal_clear_trigger <= '0';
		trigger_patt_o <= (others=>'0');
		
	elsif rising_edge(clk_mezz_i) then
	
		case registers_i(75)(1 downto 0) is
			when "01"=> 
				trigger_o <= 	trigger_meta(0) or trigger_meta(1) or trigger_meta(2) or trigger_meta(3) or
									trigger_meta(4) or trigger_meta(5) or trigger_meta(6) or trigger_meta(7);
				internal_clear_trigger <= '0';
				
			--only OR trigger implemented so far..
			when others=> 
				trigger_o <= '0';
				internal_clear_trigger <= '0';
		end case;
	end if;
end process;
--
end rtl;