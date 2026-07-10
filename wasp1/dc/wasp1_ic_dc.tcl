# wasp1 ASIC synthesis entry for Synopsys Design Compiler.
#
# Required environment:
#   WASP1_TARGET_LIBRARY  whitespace-separated target .db libraries
#   WASP1_LINK_LIBRARY    optional extra link .db libraries
#   WASP1_SYMBOL_LIBRARY  optional symbol library
#
# Optional environment:
#   WASP1_SYNTH_EFFORT    low | medium | high, default medium

set script_dir [file dirname [file normalize [info script]]]
set wasp1_dir  [file normalize [file join $script_dir ..]]
set repo_root  [file normalize [file join $wasp1_dir ..]]
set out_dir    [file normalize [file join $wasp1_dir build dc_ic]]
set rpt_dir    [file normalize [file join $wasp1_dir logs dc_ic]]

file mkdir $out_dir
file mkdir $rpt_dir

if {![info exists ::env(WASP1_TARGET_LIBRARY)]} {
  error "Set WASP1_TARGET_LIBRARY to the target standard-cell .db library list"
}

set target_library [split $::env(WASP1_TARGET_LIBRARY)]
if {[info exists ::env(WASP1_LINK_LIBRARY)]} {
  set link_library [concat "*" $target_library [split $::env(WASP1_LINK_LIBRARY)]]
} else {
  set link_library [concat "*" $target_library]
}
if {[info exists ::env(WASP1_SYMBOL_LIBRARY)]} {
  set symbol_library [split $::env(WASP1_SYMBOL_LIBRARY)]
}

set_app_var search_path [concat $search_path \
  [list $repo_root $wasp1_dir [file join $repo_root common rtl] [file join $repo_root debug rtl]]]
set_app_var target_library $target_library
set_app_var link_library $link_library

define_design_lib WORK -path [file join $out_dir WORK]

proc wasp1_read_filelist {filelist repo_root wasp1_dir} {
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
      error "Nested -f entries are not supported in this DC template: $line"
    } else {
      lappend files [file normalize [file join $wasp1_dir $line]]
    }
  }
  close $fh

  set vcs_opts [list -sverilog +define+WASP1_TARGET_IC]
  foreach inc $incdirs {
    lappend vcs_opts "+incdir+$inc"
  }

  analyze -format sverilog -vcs [join $vcs_opts " "] {*}$files
}

wasp1_read_filelist [file join $wasp1_dir filelists wasp1_synth_ic.f] $repo_root $wasp1_dir
elaborate wasp1
current_design wasp1
link
uniquify

source [file join $script_dir wasp1_ic_constraints.sdc]

check_design > [file join $rpt_dir check_design.rpt]
report_clock > [file join $rpt_dir clocks.rpt]

set effort medium
if {[info exists ::env(WASP1_SYNTH_EFFORT)]} {
  set effort $::env(WASP1_SYNTH_EFFORT)
}

if {$effort eq "high"} {
  compile_ultra -no_autoungroup
} else {
  compile -map_effort $effort
}

report_area -hierarchy > [file join $rpt_dir area_hier.rpt]
report_timing -max_paths 50 -delay_type max > [file join $rpt_dir timing_max.rpt]
report_timing -max_paths 50 -delay_type min > [file join $rpt_dir timing_min.rpt]
report_power -hierarchy > [file join $rpt_dir power_hier.rpt]
report_reference -hierarchy > [file join $rpt_dir references.rpt]

write -format ddc -hierarchy -output [file join $out_dir wasp1.ddc]
write -format verilog -hierarchy -output [file join $out_dir wasp1_mapped.v]
write_sdc [file join $out_dir wasp1_mapped.sdc]

quit
