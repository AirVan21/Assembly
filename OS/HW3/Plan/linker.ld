ENTRY(_start)

SECTIONS
{
  . = 0x100000 + SIZEOF_HEADERS;
  .text  ALIGN (0x1000)  :  { *(.text) }
}