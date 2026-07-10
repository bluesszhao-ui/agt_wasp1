# wasp1 Xilinx Virtex-7 synthesis entry for Vivado.
#
# Optional environment:
#   WASP1_VIVADO_PART  default xc7vx485tffg1761-2

set script_dir [file dirname [file normalize [info script]]]
set wasp1_dir  [file normalize [file join $script_dir ..]]
set repo_root  [file normalize [file join $wasp1_dir ..]]
set out_dir    [file normalize [file join $wasp1_dir build vivado_v7]]
set rpt_dir    [file normalize [file join $wasp1_dir logs vivado_v7]]

file mkdir $out_dir
file mkdir $rpt_dir

if {[info exists ::env(WASP1_VIVADO_PART)]} {
  set part $::env(WASP1_VIVADO_PART)
} else {
  set part xc7vx485tffg1761-2
}

proc wasp1_collect_filelist {filelist wasp1_dir} {
  set incdirs {}
  set files {}
  set fh [open $filelist r]
  while {[gets $fh line] >= 0} {
    set line [string trim $line]
    if {$line eq "" || [string match "#*" $line]} {
      continue
    }
    if {[string match "+incdir+*" $line]} {
      set inc [string range $line 8 end]
      lappend incdirs [file normalize [file join $wasp1_dir $inc]]
    } elseif {[string match "-f *" $line]} {
      error "Nested -f entries are not supported in this Vivado template: $line"
    } else {
      lappend files [file normalize [file join $wasp1_dir $line]]
    }
  }
  close $fh
  return [list $incdirs $files]
}

lassign [wasp1_collect_filelist [file join $wasp1_dir filelists wasp1.f] $wasp1_dir] incdirs files

read_verilog -sv -define WASP1_TARGET_FPGA_XILINX_VIRTEX7 -include_dirs $incdirs {*}$files
read_xdc [file join $script_dir wasp1_v7_constraints.xdc]

synth_design -top wasp1 -part $part -flatten_hierarchy rebuilt

write_checkpoint -force [file join $out_dir wasp1_synth.dcp]
write_verilog -force [file join $out_dir wasp1_synth.v]

report_utilization -hierarchical -file [file join $rpt_dir utilization_hier.rpt]
report_timing_summary -file [file join $rpt_dir timing_summary.rpt]
report_clock_utilization -file [file join $rpt_dir clock_utilization.rpt]
report_ram_utilization -file [file join $rpt_dir ram_utilization.rpt]

exit
