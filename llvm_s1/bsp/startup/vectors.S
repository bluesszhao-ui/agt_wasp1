  # Reserved vector table symbol for future vectored-trap startup variants.
  .section .text.vectors, "ax", @progbits
  .globl wasp1_vector_table
  .type wasp1_vector_table, @object

wasp1_vector_table:
  j __trap_entry

  .size wasp1_vector_table, . - wasp1_vector_table
