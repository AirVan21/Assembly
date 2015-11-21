ENTRY(_start)

SECTIONS
{
  . = 0x100000 + SIZEOF_HEADERS;
  
  .multiboot             : {*(.multiboot)}
  .text   ALIGN (0x1000) : {*(.text)     }
  .rodata ALIGN (0x1000) : {*(.rodata)   }
  .data   ALIGN (0x1000) : {*(.data)     }
  .bss    ALIGN (0x1000) : {*(COMMON) *(.bss)}

}