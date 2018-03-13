---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    --KICP--
--
-- PROJECT:      
-- FILE:         defs.vhd
-- AUTHOR:       e.oberla
-- EMAIL         ejo@uchicago.edu
-- DATE:         
--
-- DESCRIPTION:  type defs // register mapping
--
---------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////

--////////////////////////////////////////////////////////////////
package defs is

constant define_register_size : 	integer := 32;
constant define_address_size	:	integer := 8;

constant firmware_version 	: std_logic_vector(define_register_size-define_address_size-1 downto 0) := x"000001";
constant firmware_date 		: std_logic_vector(define_register_size-define_address_size-1 downto 0) := x"000" & x"3" & x"05";
constant firmware_year 		: std_logic_vector(define_register_size-define_address_size-1 downto 0) := x"000" & x"7e2";

constant psec4a_dac_bits : integer := 10;
constant psec4a_num_dacs : integer := 18;
constant psec4a_num_channels : integer := 8;
constant psec4a_num_adc_bits : integer := 11;

type psec4a_dac_array_type is array (psec4a_num_dacs-1 downto 0) of std_logic_vector(psec4a_dac_bits-1 downto 0);

--32 bit register (8 addr + 24 data)
type register_array_type is array (127 downto 0) of std_logic_vector(define_register_size-define_address_size-1 downto 0);

type read_register_array_type is array (31 downto 0) of std_logic_vector(15 downto 0);

end defs;