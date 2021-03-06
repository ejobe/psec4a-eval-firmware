-- megafunction wizard: %ALTIOBUF%
-- GENERATION: STANDARD
-- VERSION: WM1.0
-- MODULE: altiobuf_in 

-- ============================================================
-- File Name: ibuf.vhd
-- Megafunction Name(s):
-- 			altiobuf_in
--
-- Simulation Library Files(s):
-- 			cycloneiii
-- ============================================================
-- ************************************************************
-- THIS IS A WIZARD-GENERATED FILE. DO NOT EDIT THIS FILE!
--
-- 12.1 Build 177 11/07/2012 SJ Full Version
-- ************************************************************


--Copyright (C) 1991-2012 Altera Corporation
--Your use of Altera Corporation's design tools, logic functions 
--and other software and tools, and its AMPP partner logic 
--functions, and any output files from any of the foregoing 
--(including device programming or simulation files), and any 
--associated documentation or information are expressly subject 
--to the terms and conditions of the Altera Program License 
--Subscription Agreement, Altera MegaCore Function License 
--Agreement, or other applicable license agreement, including, 
--without limitation, that your use is for the sole purpose of 
--programming logic devices manufactured by Altera and sold by 
--Altera or its authorized distributors.  Please refer to the 
--applicable agreement for further details.


--altiobuf_in CBX_AUTO_BLACKBOX="ALL" DEVICE_FAMILY="Cyclone III" ENABLE_BUS_HOLD="FALSE" NUMBER_OF_CHANNELS=1 USE_DIFFERENTIAL_MODE="FALSE" USE_DYNAMIC_TERMINATION_CONTROL="FALSE" datain dataout
--VERSION_BEGIN 12.1 cbx_altiobuf_in 2012:11:07:18:03:59:SJ cbx_mgl 2012:11:07:18:06:30:SJ cbx_stratixiii 2012:11:07:18:03:59:SJ cbx_stratixv 2012:11:07:18:03:59:SJ  VERSION_END

 LIBRARY cycloneiii;
 USE cycloneiii.all;

--synthesis_resources = cycloneiii_io_ibuf 1 
 LIBRARY ieee;
 USE ieee.std_logic_1164.all;

 ENTITY  ibuf_iobuf_in_47i IS 
	 PORT 
	 ( 
		 datain	:	IN  STD_LOGIC_VECTOR (0 DOWNTO 0);
		 dataout	:	OUT  STD_LOGIC_VECTOR (0 DOWNTO 0)
	 ); 
 END ibuf_iobuf_in_47i;

 ARCHITECTURE RTL OF ibuf_iobuf_in_47i IS

	 SIGNAL  wire_ibufa_o	:	STD_LOGIC;
	 COMPONENT  cycloneiii_io_ibuf
	 GENERIC 
	 (
		bus_hold	:	STRING := "false";
		differential_mode	:	STRING := "false";
		simulate_z_as	:	STRING := "Z";
		lpm_type	:	STRING := "cycloneiii_io_ibuf"
	 );
	 PORT
	 ( 
		i	:	IN STD_LOGIC := '0';
		ibar	:	IN STD_LOGIC := '0';
		o	:	OUT STD_LOGIC
	 ); 
	 END COMPONENT;
 BEGIN

	dataout(0) <= wire_ibufa_o;
	ibufa :  cycloneiii_io_ibuf
	  GENERIC MAP (
		bus_hold => "false",
		differential_mode => "false"
	  )
	  PORT MAP ( 
		i => datain(0),
		o => wire_ibufa_o
	  );

 END RTL; --ibuf_iobuf_in_47i
--VALID FILE


LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY ibuf IS
	PORT
	(
		datain		: IN STD_LOGIC_VECTOR (0 DOWNTO 0);
		dataout		: OUT STD_LOGIC_VECTOR (0 DOWNTO 0)
	);
END ibuf;


ARCHITECTURE RTL OF ibuf IS

	SIGNAL sub_wire0	: STD_LOGIC_VECTOR (0 DOWNTO 0);



	COMPONENT ibuf_iobuf_in_47i
	PORT (
			datain	: IN STD_LOGIC_VECTOR (0 DOWNTO 0);
			dataout	: OUT STD_LOGIC_VECTOR (0 DOWNTO 0)
	);
	END COMPONENT;

BEGIN
	dataout    <= sub_wire0(0 DOWNTO 0);

	ibuf_iobuf_in_47i_component : ibuf_iobuf_in_47i
	PORT MAP (
		datain => datain,
		dataout => sub_wire0
	);



END RTL;

-- ============================================================
-- CNX file retrieval info
-- ============================================================
-- Retrieval info: PRIVATE: INTENDED_DEVICE_FAMILY STRING "Cyclone III"
-- Retrieval info: PRIVATE: SYNTH_WRAPPER_GEN_POSTFIX STRING "0"
-- Retrieval info: LIBRARY: altera_mf altera_mf.altera_mf_components.all
-- Retrieval info: CONSTANT: INTENDED_DEVICE_FAMILY STRING "Cyclone III"
-- Retrieval info: CONSTANT: enable_bus_hold STRING "FALSE"
-- Retrieval info: CONSTANT: number_of_channels NUMERIC "1"
-- Retrieval info: CONSTANT: use_differential_mode STRING "FALSE"
-- Retrieval info: CONSTANT: use_dynamic_termination_control STRING "FALSE"
-- Retrieval info: USED_PORT: datain 0 0 1 0 INPUT NODEFVAL "datain[0..0]"
-- Retrieval info: USED_PORT: dataout 0 0 1 0 OUTPUT NODEFVAL "dataout[0..0]"
-- Retrieval info: CONNECT: @datain 0 0 1 0 datain 0 0 1 0
-- Retrieval info: CONNECT: dataout 0 0 1 0 @dataout 0 0 1 0
-- Retrieval info: GEN_FILE: TYPE_NORMAL ibuf.vhd TRUE
-- Retrieval info: GEN_FILE: TYPE_NORMAL ibuf.inc FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL ibuf.cmp FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL ibuf.bsf FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL ibuf_inst.vhd FALSE
-- Retrieval info: LIB_FILE: cycloneiii
