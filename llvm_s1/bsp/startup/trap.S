  # Stage-1 trap entry.
  #
  # This stub forwards only mcause/mepc/mtval to C and does not yet save the
  # full integer context. It is suitable for early fatal-trap diagnostics, not
  # for a preemptive or nested interrupt runtime.
  .section .text.trap, "ax", @progbits
  .globl __trap_entry
  .type __trap_entry, @function

__trap_entry:
  # Pass the key machine trap CSRs as the first three C arguments.
  csrr a0, mcause
  csrr a1, mepc
  csrr a2, mtval
  call wasp1_trap_handler
  mret

  .size __trap_entry, . - __trap_entry
