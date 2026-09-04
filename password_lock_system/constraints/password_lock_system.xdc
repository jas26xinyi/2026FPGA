# HX7A75A / XC7A75T-FGG484-2 dedicated constraints.
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

set_property PACKAGE_PIN Y18 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
create_clock -name sys_clk -period 20.000 [get_ports sys_clk]

set_property PACKAGE_PIN E3  [get_ports {key_n[0]}]
set_property PACKAGE_PIN G4  [get_ports {key_n[1]}]
set_property PACKAGE_PIN P19 [get_ports {key_n[2]}]
set_property PACKAGE_PIN R19 [get_ports {key_n[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {key_n[*]}]
set_property PULLUP true [get_ports {key_n[*]}]
set_property PACKAGE_PIN N14 [get_ports {sw[0]}]
set_property PACKAGE_PIN P16 [get_ports {sw[1]}]
set_property PACKAGE_PIN R17 [get_ports {sw[2]}]
set_property PACKAGE_PIN N15 [get_ports {sw[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[*]}]

# The connected keypad presents its column group on P2IO[0:3] and row group
# on P2IO[4:7]. Swapping the FPGA port roles here corrects the observed
# transposed key matrix without changing the physical ribbon cable.
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

set_property PACKAGE_PIN AA6 [get_ports {led[0]}]
set_property PACKAGE_PIN V7  [get_ports {led[1]}]
set_property PACKAGE_PIN W7  [get_ports {led[2]}]
set_property PACKAGE_PIN AB7 [get_ports {led[3]}]
set_property PACKAGE_PIN P20 [get_ports buzzer_n]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*] buzzer_n}]

set_property PACKAGE_PIN M20 [get_ports flash_cs_n]
set_property PACKAGE_PIN K13 [get_ports flash_hold_n]
set_property PACKAGE_PIN M13 [get_ports flash_miso]
set_property PACKAGE_PIN K14 [get_ports flash_sclk]
set_property PACKAGE_PIN K17 [get_ports flash_wp_n]
set_property PACKAGE_PIN L13 [get_ports flash_mosi]
set_property IOSTANDARD LVCMOS33 [get_ports {flash_cs_n flash_hold_n flash_miso flash_sclk flash_wp_n flash_mosi}]

# Raspberry Pi 5 UART link on the unused GPIOA 40-pin expansion header.
# GPIOA_0 / header pin 1: FPGA TX -> Pi GPIO15/RXD0 (physical pin 10)
# GPIOA_1 / header pin 2: FPGA RX <- Pi GPIO14/TXD0 (physical pin 8)
# Connect grounds as well; do not connect either board's 3.3 V or 5 V pin.
set_property PACKAGE_PIN J16 [get_ports rpi_uart_tx]
set_property PACKAGE_PIN H13 [get_ports rpi_uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports {rpi_uart_tx rpi_uart_rx}]
set_property PULLUP true [get_ports rpi_uart_rx]
