derive_pll_clocks -use_tan_name
derive_clock_uncertainty 
create_clock -period 48MHz 	[get_ports USB_IFCLK]
