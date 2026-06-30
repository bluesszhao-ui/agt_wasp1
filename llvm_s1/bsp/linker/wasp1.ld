OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
  OTP   (rx)  : ORIGIN = 0x00000000, LENGTH = 0x0000ff00
  ISRAM (rwx) : ORIGIN = 0x10000000, LENGTH = 0x00010000
  DSRAM (rwx) : ORIGIN = 0x20000000, LENGTH = 0x00010000
}

PROVIDE(__stack_size = 0x00001000);
PROVIDE(__heap_size = 0x00001000);

SECTIONS
{
  .text : ALIGN(4)
  {
    KEEP(*(.text.start))
    *(.text .text.*)
  } > OTP

  .rodata : ALIGN(4)
  {
    *(.srodata .srodata.*)
    *(.rodata .rodata.*)
  } > OTP

  __fasttext_load_start = LOADADDR(.fasttext);
  .fasttext : ALIGN(4)
  {
    __fasttext_start = .;
    *(.fasttext .fasttext.*)
    __fasttext_end = .;
  } > ISRAM AT > OTP

  __data_load_start = LOADADDR(.data);
  .data : ALIGN(4)
  {
    __global_pointer$ = . + 0x800;
    __data_start = .;
    *(.sdata .sdata.*)
    *(.data .data.*)
    __data_end = .;
  } > DSRAM AT > OTP

  .bss (NOLOAD) : ALIGN(4)
  {
    __bss_start = .;
    *(.sbss .sbss.*)
    *(.bss .bss.*)
    *(COMMON)
    __bss_end = .;
  } > DSRAM

  .heap (NOLOAD) : ALIGN(8)
  {
    __heap_start = .;
    . += __heap_size;
    __heap_end = .;
  } > DSRAM

  .stack (NOLOAD) : ALIGN(16)
  {
    __stack_bottom = .;
    . += __stack_size;
    __stack_top = .;
  } > DSRAM

  /DISCARD/ :
  {
    *(.comment)
    *(.riscv.attributes)
  }
}
