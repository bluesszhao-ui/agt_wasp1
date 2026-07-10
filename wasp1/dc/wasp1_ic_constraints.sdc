# wasp1 ASIC synthesis constraints.
#
# This is the first technology-neutral SDC for logic synthesis. Replace the
# clock periods, IO budgets, driving cells, loads, and uncertainty values with
# the selected process/library package before signoff use.

set WASP1_HCLK_PERIOD_NS 10.000
set WASP1_JTAG_TCK_PERIOD_NS 100.000

create_clock -name hclk -period $WASP1_HCLK_PERIOD_NS [get_ports hclk_i]
create_clock -name jtag_tck -period $WASP1_JTAG_TCK_PERIOD_NS [get_ports jtag_tck_i]

set_clock_groups -asynchronous \
  -group [get_clocks hclk] \
  -group [get_clocks jtag_tck]

set_clock_uncertainty 0.250 [get_clocks hclk]
set_clock_uncertainty 1.000 [get_clocks jtag_tck]

set_input_delay  2.000 -clock hclk [remove_from_collection [all_inputs] [get_ports {hclk_i hresetn_i jtag_tck_i jtag_trst_ni jtag_tms_i jtag_tdi_i}]]
set_output_delay 2.000 -clock hclk [all_outputs]

set_input_delay  5.000 -clock jtag_tck [get_ports {jtag_tms_i jtag_tdi_i}]
set_output_delay 5.000 -clock jtag_tck [get_ports {jtag_tdo_o}]

set_false_path -from [get_ports hresetn_i]
set_false_path -from [get_ports jtag_trst_ni]

# The current top has no scan/DFT ports. Add scan clock, scan enable, test mode,
# and memory BIST constraints when DFT collateral exists.
