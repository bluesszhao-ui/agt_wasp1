OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
  ISRAM (rwx) : ORIGIN = 0x10000000, LENGTH = 0x00010000
}

PROVIDE(__stack_size = 0x00001000);

SECTIONS
{
  .text : ALIGN(4)
  {
    KEEP(*(.text.start))
    *(.text .text.*)
  } > ISRAM

  .rodata : ALIGN(4)
  {
    *(.srodata .srodata.*)
    *(.rodata .rodata.*)
  } > ISRAM

  .data : ALIGN(4)
  {
    __global_pointer$ = . + 0x800;
    *(.sdata .sdata.*)
    *(.data .data.*)
  } > ISRAM

  .bss (NOLOAD) : ALIGN(4)
  {
    __bss_start = .;
    *(.sbss .sbss.*)
    *(.bss .bss.*)
    *(COMMON)
    __bss_end = .;
  } > ISRAM

  .stack (NOLOAD) : ALIGN(16)
  {
    __stack_bottom = .;
    . += __stack_size;
    __stack_top = .;
  } > ISRAM

  /DISCARD/ :
  {
    *(.comment)
    *(.riscv.attributes)
  }
}
