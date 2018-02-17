-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- e oberla                                                                  --
-- DATE: Mar. 2010                                                           --
-- PROJECT: psTDC_2 tester firmware                                          --
-- NAME: DAC_MAIN                                                            --
-- Description:                                                              --
--      DAC module                                                           --
--    -- for use with DAC_SERIALIZATION.vhd--                                --
--    -- parallel control to two octal DACs--                                                                      --
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.defs.all;

entity DAC_MAIN_LTC2600 is
	port(
			xCLKDAC			: in 	std_logic;  --internal DACclk
			xCLK_REFRESH	: in	std_logic;  --internal REFRESHclk
			xCLR_ALL		: in	std_logic;
			registers_i	:	in	register_array_type;
			SDATOUT1		: in	std_logic;
			SDATOUT2		: in	std_logic;
			DACCLK1			: out	std_logic;  --copy of DACclk to external
			DACCLK2			: out	std_logic;  --ditto, second DAC
			LOAD1			: out 	std_logic;
			LOAD2			: out	std_logic;  --Load signal (active low)
			CLR_BAR1		: out 	std_logic;
			CLR_BAR2		: out	std_logic;  --Clear (currently inactive)
			SDATIN1			: out 	std_logic;  --serial data to DAC1
			SDATIN2			: out	std_logic); --serial data to DAC2
	end DAC_MAIN_LTC2600;
	
architecture Behavioral of DAC_MAIN_LTC2600 is
-------------------------------------------------------------------------------
-- SIGNALS 
-------------------------------------------------------------------------------	
	signal CLR		: std_logic;
	--signal DATIN1	: std_logic;
	--signal DATIN2   : std_logic;
	signal UPDATE   : std_logic;
	
	signal DAC_A_0	: std_logic_vector(23 downto 0);
	signal DAC_B_0	: std_logic_vector(23 downto 0);
	signal DAC_C_0	: std_logic_vector(23 downto 0);
	signal DAC_D_0	: std_logic_vector(23 downto 0);
	signal DAC_E_0	: std_logic_vector(23 downto 0);
	signal DAC_F_0	: std_logic_vector(23 downto 0);
	signal DAC_G_0	: std_logic_vector(23 downto 0);
	signal DAC_H_0	: std_logic_vector(23 downto 0);
	signal DAC_A_1	: std_logic_vector(23 downto 0);
	signal DAC_B_1	: std_logic_vector(23 downto 0);
	signal DAC_C_1	: std_logic_vector(23 downto 0);
	signal DAC_D_1	: std_logic_vector(23 downto 0);
	signal DAC_E_1	: std_logic_vector(23 downto 0);
	signal DAC_F_1	: std_logic_vector(23 downto 0);
	signal DAC_G_1	: std_logic_vector(23 downto 0);
	signal DAC_H_1	: std_logic_vector(23 downto 0);

-------------------------------------------------------------------------------
-- COMPONENTS 
-------------------------------------------------------------------------------
	component DAC_SERIALIZER    --call DAC_SERIALIZER.vhd
	port(
		xCLK             : in    std_logic;      -- DAC clk ( < 50MHz ) 
        xCLR_ALL		 : in	 std_logic;
        xUPDATE          : in    std_logic;
        xDAC_A           : in    std_logic_vector (23 downto 0);  --DAC takes
        xDAC_B           : in    std_logic_vector (23 downto 0);  --24 bit word
        xDAC_C           : in    std_logic_vector (23 downto 0);  
        xDAC_D           : in    std_logic_vector (23 downto 0);
        xDAC_E           : in    std_logic_vector (23 downto 0); 
        xDAC_F           : in    std_logic_vector (23 downto 0); 
        xDAC_G           : in    std_logic_vector (23 downto 0); 
        xDAC_H           : in    std_logic_vector (23 downto 0); 
        xLOAD            : out   std_logic;     -- load DACs- active low
        xCLR_BAR         : out   std_logic;     -- Asynch clear
        xSERIAL_DATOUT   : out   std_logic);    -- Serial data to DAC reg
	end component;
-------------------------------------------------------------------------------  
begin  -- Behavioral
-------------------------------------------------------------------------------
	UPDATE <= xCLK_REFRESH;       --1 Hz
	DACCLK1 <= xCLKDAC;	
	DACCLK2	<= xCLKDAC;
	--TTHRSH <= x"FFF";
	
--------------------------------------------------------------------------------
-- update DAC values with 4 COMMAND and 4 ADDRESS bits
-- note: these assignments are easily changed to match board layout
--------------------------------------------------------------------------------	
proc_assign_dac_value : process(xCLKDAC)
begin
if rising_edge(xCLKDAC) then
	DAC_A_0		<=	"11110000"	&	x"0000";
	DAC_B_0		<=	"11110001"	&	x"0000";   
	DAC_C_0		<=	"11110010"	&	x"0000";   
	DAC_D_0		<=	"00110011"	&	x"0000";
	DAC_E_0		<=	"00110100"	&	x"0000";
	DAC_F_0		<=	"00110101"	&	x"0000";	
	DAC_G_0		<=	"00110110"	&	x"0000";
	DAC_H_0		<=	"00110111"	&	x"0000";
	
	DAC_A_1		<=	"00110000"	&	registers_i(104)(15 downto 0);	
	DAC_B_1		<=	"00110001"	&	x"0000";
	DAC_C_1		<=	"00110010"	&	x"0000";
	DAC_D_1		<=	"00110011"	&	x"0000";
	DAC_E_1		<=	"00110100"	&	registers_i(105)(15 downto 0);
	DAC_F_1		<=	"00110101"	&	x"0000";
	DAC_G_1		<=	"00110110"	&	x"0000";
	DAC_H_1		<=	"00110111"	&	x"0000";
end if;
end process;
-------------------------------------------------------------------------------
	xDAC_SERIALIZER_0 : DAC_SERIALIZER
	port map(
		xCLK         => xCLKDAC,    
        xCLR_ALL	 => xCLR_ALL,
        xUPDATE      => UPDATE,    
        xDAC_A       => DAC_A_0,    
        xDAC_B       => DAC_B_0,    
        xDAC_C       => DAC_C_0,  
        xDAC_D       => DAC_D_0,    
        xDAC_E       => DAC_E_0,    
        xDAC_F       => DAC_F_0,    
        xDAC_G       => DAC_G_0,    
        xDAC_H       => DAC_H_0,    
  --      xSERIAL_DATIN	=> SDATOUT1,
        xLOAD        => LOAD1,
        xCLR_BAR     => CLR_BAR1,    
        xSERIAL_DATOUT	=> SDATIN1);

 ------------------------------------------------------------------------------- 
	xDAC_SERIALIZER_1 : DAC_SERIALIZER
	port map(
		xCLK         => xCLKDAC,    
        xCLR_ALL	 => xCLR_ALL,
        xUPDATE      => UPDATE,    
        xDAC_A       => DAC_A_1,    
        xDAC_B       => DAC_B_1,    
        xDAC_C       => DAC_C_1,  
        xDAC_D       => DAC_D_1,    
        xDAC_E       => DAC_E_1,    
        xDAC_F       => DAC_F_1,    
        xDAC_G       => DAC_G_1,    
        xDAC_H       => DAC_H_1,    
    --    xSERIAL_DATIN	=> SDATOUT2,
        xLOAD        => LOAD2,    
        xCLR_BAR     => CLR_BAR2, 
        xSERIAL_DATOUT	=> SDATIN2);
--------------------------------------------------------------------------------
end Behavioral;