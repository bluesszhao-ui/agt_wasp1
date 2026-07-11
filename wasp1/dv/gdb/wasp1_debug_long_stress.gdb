set confirm off
set pagination off
target extended-remote localhost:3333
monitor reset halt

# Probe basic architectural visibility before the repeated stress loops.
info registers pc
x/2i 0x0
info registers dcsr

# Exercise repeated abstract GPR writes and reads with different values.
set $t0 = 0x11112222
set $t1 = 0x33334444
set $t2 = 0x55556666
info registers t0
info registers t1
info registers t2
if $t0 != 0x11112222
  echo wasp1_gdb_long_reg_t0_fail\n
  quit 1
end
if $t1 != 0x33334444
  echo wasp1_gdb_long_reg_t1_fail\n
  quit 1
end
if $t2 != 0x55556666
  echo wasp1_gdb_long_reg_t2_fail\n
  quit 1
end
printf "wasp1_gdb_long_reg_pass\n"

# Single-step once through the two-instruction OTP loop.  The simulator image
# is:
#   0x0: addi ra, ra, 1
#   0x4: jal  0x0
stepi
info registers pc
if $pc != 0x0
  echo wasp1_gdb_long_step_bad_pc\n
  quit 1
end
printf "wasp1_gdb_long_step_pass\n"

monitor reset halt

# Keep both hardware breakpoints resident at the same time and repeatedly
# continue through the two-instruction loop.
delete breakpoints
hbreak *0x0
hbreak *0x4
info breakpoints

set $hit_count = 0
while $hit_count < 6
  continue
  info registers dcsr
  info registers pc
  if $pc != 0x0 && $pc != 0x4
    echo wasp1_gdb_long_dual_hbreak_bad_pc\n
    quit 1
  end
  set $hit_count = $hit_count + 1
end
printf "wasp1_gdb_long_dual_hbreak_pass\n"

# Reset and confirm the debugger can still halt and access registers cleanly
# after the repeated breakpoint run.
delete breakpoints
monitor reset halt
info registers pc
set $s0 = 0x77778888
info registers s0
if $s0 != 0x77778888
  echo wasp1_gdb_long_post_reset_reg_fail\n
  quit 1
end
printf "wasp1_gdb_long_post_reset_pass\n"

detach
quit
