set confirm off
set pagination off
target extended-remote localhost:3333
monitor reset halt

# Confirm that OpenOCD exposes architectural PC, OTP instruction memory, and DCSR.
info registers pc
x/2i 0x0
info registers dcsr

# Exercise abstract register write/read through GDB and OpenOCD.
set $t0 = 0x12345678
info registers t0
if $t0 != 0x12345678
  echo wasp1_gdb_reg_write_read_fail\n
  quit 1
end
printf "wasp1_gdb_reg_write_read_pass\n"

# Single-step the two-instruction OTP loop and require the expected PC value.
stepi
info registers dcsr
info registers pc
if $pc != 0x0
  echo wasp1_gdb_stress_stepi_wrong_pc\n
  quit 1
end
printf "wasp1_gdb_stress_stepi_pass\n"

monitor reset halt

# Delete and reinstall the single hardware trigger, then hit address 0x0.
delete breakpoints
hbreak *0x0
continue
info registers dcsr
info registers pc
if $pc != 0x0
  echo wasp1_gdb_stress_hbreak0_wrong_pc\n
  quit 1
end
printf "wasp1_gdb_stress_hbreak0_pass\n"

# Repeat trigger delete/reinstall for the second OTP loop address.
delete breakpoints
hbreak *0x4
continue
info registers dcsr
info registers pc
if $pc != 0x4
  echo wasp1_gdb_stress_hbreak4_wrong_pc\n
  quit 1
end
printf "wasp1_gdb_stress_hbreak4_pass\n"

delete breakpoints
detach
quit
