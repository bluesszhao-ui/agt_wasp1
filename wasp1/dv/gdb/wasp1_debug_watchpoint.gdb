set confirm off
set pagination off
target extended-remote localhost:3333
monitor reset halt

# The dedicated image performs one load and one store at D-SRAM base:
#   0x00: beq  t0, zero, 0x00
#   0x04: lw   t1, 0(t0)
#   0x08: addi t1, zero, 0x55
#   0x0c: sw   t1, 0(t0)
#   0x10: jal  zero, 0x04
x/5i 0x0
set $watch_addr = 0x20000000

# The reset value of t0 keeps the hart at PC=0 without touching D-SRAM. The
# debugger opens the gate only after the target memory has been initialized and
# the read trigger is ready.
if $pc != 0x0
  echo wasp1_gdb_watch_setup_wrong_pc\n
  quit 1
end
set {unsigned int}$watch_addr = 0
if *(unsigned int *)$watch_addr != 0
  echo wasp1_gdb_watch_setup_memory_fail\n
  quit 1
end
set $t0 = $watch_addr

# A read watchpoint must report the load before the following store changes
# memory. GDB may expose the raw trigger stop at PC=0x4 or step over the
# timing=before trigger and present PC=0x8/0xc with DCSR cause=step.
rwatch *(unsigned int *)$watch_addr
continue
info registers pc
info registers dcsr
info registers tselect tdata1 tdata2
if $pc != 0x4 && $pc != 0x8 && $pc != 0xc
  echo wasp1_gdb_rwatch_wrong_pc\n
  quit 1
end
if (($dcsr >> 6) & 7) != 2 && (($dcsr >> 6) & 7) != 4
  echo wasp1_gdb_rwatch_wrong_cause\n
  quit 1
end
if *(unsigned int *)$watch_addr != 0
  echo wasp1_gdb_rwatch_memory_changed\n
  quit 1
end
printf "wasp1_gdb_rwatch_pass\n"

# Remove the read trigger and reach the store if GDB exposed an earlier stop.
delete breakpoints
while $pc != 0xc
  stepi
end

# A write watchpoint may be presented at the raw pre-store PC with memory still
# zero, or after GDB's hidden handling with PC=0x10/0x4 and the store visible.
watch *(unsigned int *)$watch_addr
continue
info registers pc
info registers dcsr
if $pc != 0xc && $pc != 0x10 && $pc != 0x4
  echo wasp1_gdb_watch_wrong_pc\n
  quit 1
end
if (($dcsr >> 6) & 7) != 2 && (($dcsr >> 6) & 7) != 4
  echo wasp1_gdb_watch_wrong_cause\n
  quit 1
end
if $pc == 0xc
  if *(unsigned int *)$watch_addr != 0
    echo wasp1_gdb_watch_raw_stop_memory_changed\n
    quit 1
  end
end

# Clear a raw trigger before stepping the store. If GDB already performed its
# hidden step, deleting the logical watchpoint is still required before detach.
delete breakpoints
if $pc == 0xc
  stepi
end
if $pc != 0x10 && $pc != 0x4
  echo wasp1_gdb_watch_post_store_wrong_pc\n
  quit 1
end
if *(unsigned int *)$watch_addr != 0x55
  echo wasp1_gdb_watch_store_missing\n
  quit 1
end
printf "wasp1_gdb_watch_pass\n"

detach
quit
