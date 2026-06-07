set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports { clk }]
create_clock -add -name clk -period 10.000 -waveform {0.000 5.000} [get_ports { clk }]

set_property -dict { PACKAGE_PIN C2 IOSTANDARD LVCMOS33 } [get_ports { rst_n }]
set_false_path -from [get_ports {rst_n}]

set_property -dict { PACKAGE_PIN D9 IOSTANDARD LVCMOS33 } [get_ports { btn0 }]
set_property -dict { PACKAGE_PIN H5 IOSTANDARD LVCMOS33 } [get_ports { led0 }]