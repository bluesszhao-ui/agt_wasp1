set confirm off
set pagination off
target extended-remote localhost:3333
monitor reset halt
info registers
info registers pc
x/1i $pc
info registers dcsr
set $wasp1_pc_before = $pc
stepi
info registers dcsr
info registers pc
if $pc == $wasp1_pc_before
  echo wasp1_gdb_stepi_no_pc_change\n
  quit 1
end
printf "wasp1_gdb_stepi_pass\n"
detach
quit
