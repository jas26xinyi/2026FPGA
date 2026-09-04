# Camera timing constraints. This file is added only when ENABLE_CAMERA=1.
create_clock -name camera_pclk -period 41.667 [get_ports camera_pclk]
set_input_delay -clock camera_pclk -max 5.0 [get_ports {camera_data[*] camera_vsync camera_href}]
set_input_delay -clock camera_pclk -min -2.0 [get_ports {camera_data[*] camera_vsync camera_href}]
set_clock_groups -asynchronous -group [get_clocks camera_pclk] -group [get_clocks -include_generated_clocks sys_clk]
