# wasp1 Xilinx Virtex-7 synthesis constraints.
#
# Pin locations are board-dependent and intentionally not assigned here. Add
# PACKAGE_PIN and IOSTANDARD constraints when a concrete FPGA board is selected.

create_clock -name hclk -period 10.000 [get_ports hclk_i]
create_clock -name jtag_tck -period 100.000 [get_ports jtag_tck_i]

set_clock_groups -asynchronous \
  -group [get_clocks hclk] \
  -group [get_clocks jtag_tck]

set_input_delay  -clock hclk 2.000 [remove_from_collection [all_inputs] [get_ports {hclk_i hresetn_i jtag_tck_i jtag_trst_ni jtag_tms_i jtag_tdi_i}]]
set_output_delay -clock hclk 2.000 [all_outputs]

set_input_delay  -clock jtag_tck 5.000 [get_ports {jtag_tms_i jtag_tdi_i}]
set_output_delay -clock jtag_tck 5.000 [get_ports {jtag_tdo_o}]

set_false_path -from [get_ports hresetn_i]
set_false_path -from [get_ports jtag_trst_ni]
