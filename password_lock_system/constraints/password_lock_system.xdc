# HX7A75A（XC7A75T-FGG484-2）专用引脚与时序约束；更换开发板时不能直接照搬。
# 配置 Bank 电压为 3.3 V，并声明所有普通 IO 使用 LVCMOS33。
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# 板载 50 MHz 系统时钟，20 ns 周期约束供综合与静态时序分析使用。
set_property PACKAGE_PIN Y18 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
create_clock -name sys_clk -period 20.000 [get_ports sys_clk]

# 独立按键 KEY1~KEY4 均低有效并启用内部上拉；KEY4 是系统复位。
set_property PACKAGE_PIN E3  [get_ports {key_n[0]}]
set_property PACKAGE_PIN G4  [get_ports {key_n[1]}]
set_property PACKAGE_PIN P19 [get_ports {key_n[2]}]
set_property PACKAGE_PIN R19 [get_ports {key_n[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {key_n[*]}]
set_property PULLUP true [get_ports {key_n[*]}]
# 拨码开关 SW1~SW4；当前业务逻辑只使用 sw[0] 启动普通密码输入。
set_property PACKAGE_PIN N14 [get_ports {sw[0]}]
set_property PACKAGE_PIN P16 [get_ports {sw[1]}]
set_property PACKAGE_PIN R17 [get_ports {sw[2]}]
set_property PACKAGE_PIN N15 [get_ports {sw[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[*]}]

# P2 扩展口连接 4×4 矩阵键盘；此处按实测交换行列角色，修正转置而无需改排线。
# row_n 是带上拉的低有效输入，col_n 是扫描器逐列拉低的输出。
set_property PACKAGE_PIN V2 [get_ports {keypad_row_n[0]}]
set_property PACKAGE_PIN R3 [get_ports {keypad_row_n[1]}]
set_property PACKAGE_PIN R2 [get_ports {keypad_row_n[2]}]
set_property PACKAGE_PIN W2 [get_ports {keypad_row_n[3]}]
set_property PACKAGE_PIN T3 [get_ports {keypad_col_n[0]}]
set_property PACKAGE_PIN T1 [get_ports {keypad_col_n[1]}]
set_property PACKAGE_PIN U1 [get_ports {keypad_col_n[2]}]
set_property PACKAGE_PIN U2 [get_ports {keypad_col_n[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {keypad_row_n[*] keypad_col_n[*]}]
set_property PULLUP true [get_ports {keypad_row_n[*]}]

# 八位数码管：seg_n[7:0] 为段选，seg_sel[7:0] 为位选，均低有效。
set_property PACKAGE_PIN AB18 [get_ports {seg_n[0]}]
set_property PACKAGE_PIN U17  [get_ports {seg_n[1]}]
set_property PACKAGE_PIN U18  [get_ports {seg_n[2]}]
set_property PACKAGE_PIN P14  [get_ports {seg_n[3]}]
set_property PACKAGE_PIN R14  [get_ports {seg_n[4]}]
set_property PACKAGE_PIN R18  [get_ports {seg_n[5]}]
set_property PACKAGE_PIN T18  [get_ports {seg_n[6]}]
set_property PACKAGE_PIN N17  [get_ports {seg_n[7]}]
set_property PACKAGE_PIN AA18 [get_ports {seg_sel[0]}]
set_property PACKAGE_PIN W17  [get_ports {seg_sel[1]}]
set_property PACKAGE_PIN V17  [get_ports {seg_sel[2]}]
set_property PACKAGE_PIN AB20 [get_ports {seg_sel[3]}]
set_property PACKAGE_PIN AA19 [get_ports {seg_sel[4]}]
set_property PACKAGE_PIN V19  [get_ports {seg_sel[5]}]
set_property PACKAGE_PIN V18  [get_ports {seg_sel[6]}]
set_property PACKAGE_PIN Y19  [get_ports {seg_sel[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg_n[*] seg_sel[*]}]

# 4 个状态 LED 与板载蜂鸣器；蜂鸣器 P20 已实测为高电平有效。
set_property PACKAGE_PIN AA6 [get_ports {led[0]}]
set_property PACKAGE_PIN V7  [get_ports {led[1]}]
set_property PACKAGE_PIN W7  [get_ports {led[2]}]
set_property PACKAGE_PIN AB7 [get_ports {led[3]}]
set_property PACKAGE_PIN P20 [get_ports buzzer_n]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*] buzzer_n}]

# 用户数据 W25Q64 的 SPI 接口，与用于 FPGA 上电配置的配置 Flash 不是同一逻辑用途。
set_property PACKAGE_PIN M20 [get_ports flash_cs_n]
set_property PACKAGE_PIN K13 [get_ports flash_hold_n]
set_property PACKAGE_PIN M13 [get_ports flash_miso]
set_property PACKAGE_PIN K14 [get_ports flash_sclk]
set_property PACKAGE_PIN K17 [get_ports flash_wp_n]
set_property PACKAGE_PIN L13 [get_ports flash_mosi]
set_property IOSTANDARD LVCMOS33 [get_ports {flash_cs_n flash_hold_n flash_miso flash_sclk flash_wp_n flash_mosi}]

# 树莓派 5 UART 使用开发板 GPIOA 扩展口：FPGA TX→Pi GPIO15/RXD0（物理 10 脚），
# FPGA RX←Pi GPIO14/TXD0（物理 8 脚）。两板必须共地，禁止互接 3.3 V 或 5 V 电源脚。
set_property PACKAGE_PIN J16 [get_ports rpi_uart_tx]
set_property PACKAGE_PIN H13 [get_ports rpi_uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports {rpi_uart_tx rpi_uart_rx}]
set_property PULLUP true [get_ports rpi_uart_rx]
