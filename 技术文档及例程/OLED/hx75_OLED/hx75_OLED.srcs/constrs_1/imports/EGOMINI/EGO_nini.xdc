## Clock signal
set_property PACKAGE_PIN P17 [get_ports clk]
set_property PACKAGE_PIN R15 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

## LEDs
set_property IOSTANDARD LVCMOS33 [get_ports {led[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN R10 [get_ports {led[7]}]
set_property PACKAGE_PIN R11 [get_ports {led[6]}]
set_property PACKAGE_PIN U8 [get_ports {led[5]}]
set_property PACKAGE_PIN P5 [get_ports {led[4]}]
set_property PACKAGE_PIN N5 [get_ports {led[3]}]
set_property PACKAGE_PIN T4 [get_ports {led[2]}]
set_property PACKAGE_PIN T5 [get_ports {led[1]}]
set_property PACKAGE_PIN T3 [get_ports {led[0]}]

## Buttons
set_property -dict {PACKAGE_PIN L6 IOSTANDARD LVCMOS33} [get_ports {btn[0]}]
set_property -dict {PACKAGE_PIN L4 IOSTANDARD LVCMOS33} [get_ports {btn[1]}]
set_property -dict {PACKAGE_PIN L5 IOSTANDARD LVCMOS33} [get_ports {btn[2]}]
set_property -dict {PACKAGE_PIN U1 IOSTANDARD LVCMOS33} [get_ports {btn[3]}]

##SEGS and Seg_Ctrl
set_property -dict {PACKAGE_PIN M2 IOSTANDARD LVCMOS33} [get_ports {an[0]}]
set_property -dict {PACKAGE_PIN K5 IOSTANDARD LVCMOS33} [get_ports {an[1]}]

set_property -dict {PACKAGE_PIN K6 IOSTANDARD LVCMOS33} [get_ports {seg[0]}]
set_property -dict {PACKAGE_PIN L1 IOSTANDARD LVCMOS33} [get_ports {seg[1]}]
set_property -dict {PACKAGE_PIN K3 IOSTANDARD LVCMOS33} [get_ports {seg[2]}]
set_property -dict {PACKAGE_PIN M1 IOSTANDARD LVCMOS33} [get_ports {seg[3]}]
set_property -dict {PACKAGE_PIN L3 IOSTANDARD LVCMOS33} [get_ports {seg[4]}]
set_property -dict {PACKAGE_PIN N2 IOSTANDARD LVCMOS33} [get_ports {seg[5]}]
set_property -dict {PACKAGE_PIN N1 IOSTANDARD LVCMOS33} [get_ports {seg[6]}]
set_property -dict {PACKAGE_PIN M3 IOSTANDARD LVCMOS33} [get_ports {seg[7]}]

## Switches
set_property -dict {PACKAGE_PIN V1 IOSTANDARD LVCMOS33} [get_ports {sw[7]}]
set_property -dict {PACKAGE_PIN U4 IOSTANDARD LVCMOS33} [get_ports {sw[6]}]
set_property -dict {PACKAGE_PIN U3 IOSTANDARD LVCMOS33} [get_ports {sw[5]}]
set_property -dict {PACKAGE_PIN U2 IOSTANDARD LVCMOS33} [get_ports {sw[4]}]
set_property -dict {PACKAGE_PIN V2 IOSTANDARD LVCMOS33} [get_ports {sw[3]}]
set_property -dict {PACKAGE_PIN V4 IOSTANDARD LVCMOS33} [get_ports {sw[2]}]
set_property -dict {PACKAGE_PIN V5 IOSTANDARD LVCMOS33} [get_ports {sw[1]}]
set_property -dict {PACKAGE_PIN R3 IOSTANDARD LVCMOS33} [get_ports {sw[0]}]

## USB-UART Interface
set_property PACKAGE_PIN T14 [get_ports uart_rxd_in]
set_property PACKAGE_PIN T15 [get_ports uart_txd_out]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rxd_in]
set_property IOSTANDARD LVCMOS33 [get_ports uart_txd_out]

## SIP24_J1
## SPI-OLED
set_property PACKAGE_PIN T8 [get_ports sck]
set_property PACKAGE_PIN R8 [get_ports miso]
set_property PACKAGE_PIN T6 [get_ports reset_oled]
set_property PACKAGE_PIN R7 [get_ports dc]

set_property IOSTANDARD LVCMOS33 [get_ports sck]
set_property IOSTANDARD LVCMOS33 [get_ports miso]
set_property IOSTANDARD LVCMOS33 [get_ports reset_oled]
set_property IOSTANDARD LVCMOS33 [get_ports dc]

## key4x4
set_property PACKAGE_PIN U6 [get_ports {row[0]}]
set_property PACKAGE_PIN U7 [get_ports {row[1]}]
set_property PACKAGE_PIN V9 [get_ports {row[2]}]
set_property PACKAGE_PIN U9 [get_ports {row[3]}]

set_property PACKAGE_PIN R6 [get_ports {col[0]}]
set_property PACKAGE_PIN R5 [get_ports {col[1]}]
set_property PACKAGE_PIN V7 [get_ports {col[2]}]
set_property PACKAGE_PIN V6 [get_ports {col[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {row[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {row[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {row[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {row[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {col[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {col[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {col[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {col[3]}]

set_property PULLUP true [get_ports row[0]]
set_property PULLUP true [get_ports row[1]]
set_property PULLUP true [get_ports row[2]]
set_property PULLUP true [get_ports row[3]]

## XADC
set_property -dict { PACKAGE_PIN C14    IOSTANDARD LVCMOS33 } [get_ports { xadc_an_n[0] }]; #IO_L1P_AD0N_15 Sch=xadc_an_n[0]
set_property -dict { PACKAGE_PIN D14    IOSTANDARD LVCMOS33 } [get_ports { xadc_an_p[0] }]; #IO_L1P_AD0P_15 Sch=xadc_an_p[0]
set_property -dict { PACKAGE_PIN B12    IOSTANDARD LVCMOS33 } [get_ports { xadc_an_n[1] }]; #IO_L3P_AD1N_15 Sch=xadc_an_n[1]
set_property -dict { PACKAGE_PIN C12    IOSTANDARD LVCMOS33 } [get_ports { xadc_an_p[1] }]; #IO_L3P_AD1N_15 Sch=xadc_an_p[1]
set_property -dict { PACKAGE_PIN B14    IOSTANDARD LVCMOS33 } [get_ports { xadc_an_n[2] }]; #IO_L2N_AD8N_15 Sch=xadc_an_n[2]
set_property -dict { PACKAGE_PIN B13    IOSTANDARD LVCMOS33 } [get_ports { xadc_an_p[2] }]; #IO_L2N_AD8P_15 Sch=xadc_an_p[2]


