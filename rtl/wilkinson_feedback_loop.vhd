----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:44:23 11/07/2011 
-- Design Name: 
-- Module Name:    Wilkinson_Feedback_Loop - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;

use work.defs.all;

entity Wilkinson_Feedback_Loop is
        Port (
                                ENABLE_FEEDBACK     : in std_logic;
                                RESET_FEEDBACK      : in std_logic;
                                REFRESH_CLOCK       : in std_logic; --One period of this clock defines how long we count Wilkinson rate pulses
                                DAC_SYNC_CLOCK      : in std_logic; --This clock should be the same that is used for setting DACs, and should be used to avoid race conditions on setting the desired DAC values
                                WILK_MONITOR_BIT    : in std_logic;
                                DESIRED_COUNT_VALUE : in std_logic_vector(31 downto 0);
                                CURRENT_COUNT_VALUE : out std_logic_vector(31 downto 0);
                                DESIRED_DAC_VALUE   : out std_logic_vector(psec4a_dac_bits-1 downto 0)
        );
end Wilkinson_Feedback_Loop;

architecture Behavioral of Wilkinson_Feedback_Loop is
        type STATE_TYPE is ( MONITORING, SETTLING, LATCHING, CLEARING_AND_ADJUSTING );
        signal internal_STATE                   : STATE_TYPE := MONITORING;
        signal internal_COUNTER_ENABLE          : std_logic := '0';
        signal internal_COUNTER_CLEAR           : std_logic := '0';
        signal internal_COUNTER_VALUE           : unsigned(31 downto 0);
        signal internal_COUNTER_VALUE_LATCHED   : unsigned(31 downto 0);
        signal internal_DESIRED_DAC_VALUE       : unsigned(psec4a_dac_bits-1 downto 0) := "0100000000"; 
        signal internal_DESIRED_DAC_VALUE_VALID : std_logic := '1';
begin
        CURRENT_COUNT_VALUE <= std_logic_vector(internal_COUNTER_VALUE_LATCHED);

        process(REFRESH_CLOCK)
                constant INITIAL_DAC_VALUE : unsigned(psec4a_dac_bits-1 downto 0) := "0100000000"; 
                constant MINIMUM_DAC_VALUE : unsigned(psec4a_dac_bits-1 downto 0) := "0001000000";
                constant MAXIMUM_DAC_VALUE : unsigned(psec4a_dac_bits-1 downto 0) := "1100000000";
        begin
                if (rising_edge(REFRESH_CLOCK)) then
                        case internal_STATE is
                                when MONITORING =>
                                        internal_DESIRED_DAC_VALUE_VALID <= '1';
                                        internal_COUNTER_ENABLE <= '1';
                                        internal_COUNTER_CLEAR  <= '0';
                                        internal_STATE <= SETTLING;
                                when SETTLING =>
                                        internal_DESIRED_DAC_VALUE_VALID <= '1';
                                        internal_COUNTER_ENABLE <= '0';
                                        internal_COUNTER_CLEAR  <= '0';
                                        internal_STATE <= LATCHING;
                                when LATCHING =>
                                        internal_DESIRED_DAC_VALUE_VALID <= '0';
                                        internal_COUNTER_ENABLE <= '0';
                                        internal_COUNTER_CLEAR  <= '0';
                                        internal_COUNTER_VALUE_LATCHED <= internal_COUNTER_VALUE;
                                        internal_STATE <= CLEARING_AND_ADJUSTING;
                                when CLEARING_AND_ADJUSTING =>
                                        internal_DESIRED_DAC_VALUE_VALID <= '0';
                                        internal_COUNTER_ENABLE <= '0';
                                        internal_COUNTER_CLEAR  <= '1';
                                        if (ENABLE_FEEDBACK = '0') then
                                                internal_DESIRED_DAC_VALUE <= INITIAL_DAC_VALUE;
                                        else
                                                if ( internal_COUNTER_VALUE_LATCHED > unsigned(DESIRED_COUNT_VALUE) + 1000 ) then
                                                        if ( internal_DESIRED_DAC_VALUE < MAXIMUM_DAC_VALUE ) then
                                                                internal_DESIRED_DAC_VALUE <= internal_DESIRED_DAC_VALUE + 1;
                                                        end if;
                                                elsif ( internal_COUNTER_VALUE_LATCHED < unsigned(DESIRED_COUNT_VALUE) - 1000 ) then
                                                        if ( internal_DESIRED_DAC_VALUE > MINIMUM_DAC_VALUE ) then
                                                                internal_DESIRED_DAC_VALUE <= internal_DESIRED_DAC_VALUE - 1 ;
                                                        end if;
                                                end if;
                                        end if;
                                        internal_STATE <= MONITORING;
                                when others =>
                                        internal_STATE <= MONITORING;
                        end case;
                end if;
        end process;

        process(WILK_MONITOR_BIT, internal_COUNTER_ENABLE, internal_COUNTER_CLEAR) 
        begin
                if (internal_COUNTER_CLEAR = '1') then
                        internal_COUNTER_VALUE <= (others => '0');
                elsif ( internal_COUNTER_ENABLE = '1' and rising_edge(WILK_MONITOR_BIT) ) then
                        internal_COUNTER_VALUE <= internal_COUNTER_VALUE + 1;
                end if;
        end process;

        process(DAC_SYNC_CLOCK) begin
                if (rising_edge(DAC_SYNC_CLOCK)) then
                        if (internal_DESIRED_DAC_VALUE_VALID = '1') then
                                        DESIRED_DAC_VALUE <= std_logic_vector(internal_DESIRED_DAC_VALUE);
                        end if;
                end if;
        end process;

end Behavioral;