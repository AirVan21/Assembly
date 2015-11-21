    .code32

    .section .multiboot
    # Align 4 byte boundary 
    .align  4
    # MULTIBOOT_HEADER_MAGIC 
    .long 0x1BADB002
    # MULTIBOOT_HEADER_FLAGS (bit 1 in the ‘flags’ is set => Multiboot information structure must be included)
    .long 0x00000002
    # Checksum 
    .long -(0x1BADB002 + 0x00000002)

    .text
    .globl _start

# Global Entry Point
_start:

#=======================================================
# main:

    # Interrupts are disabled until OS sets up its own IDT. (c)
    
    # Saves pointer to multiboot information structure
    movl %ebx, multiboot_info_addr
    # Gets flags
    movl (%ebx), %ebx
    # Saves flags
    movl %ebx, multiboot_flags

    # Sets GDT 
    lgdt GDTR
    # Far jmp CODE_SELECTOR : CodeWithOwnGDT
    ljmp $0x08, $code_with_own_GDT 

 code_with_own_GDT:

    # DATA_SELECTOR
    mov $0x10, %ax
    mov %ax, %ds
    # STACK_SELECTOR
    mov %ax, %ss
    # Init ESP with stack: 
    movl $stack, %esp
    lidt IDTR

    call clrscr

    call print_cmdline
    call print_memorymap
    call find_rsd_pointer
    call handle_rsd_table

deadloop:
    jmp deadloop

#=======================================================
# Functions

print_cmdline:
    
    pushl %eax
    pushl %ebx

    leal msg_cmd_line, %ebx
    call print_line_until_null

    movl multiboot_flags, %eax
    # multiboot_flags[2] bit for CMDLINE
    test $0x04, %eax
    jz out_print_cmdline

    movl multiboot_info_addr, %eax
    addl $CMDLINE_OFFSET, %eax
    # CMDLINE address
    movl (%eax), %ebx

    call print_line_until_null
    call videomem_newline

  out_print_cmdline:
    
    popl %ebx
    popl %eax 

    ret

# Gets mmap_addr and mmap_length if possible
# Calls print_memory_ranges
print_memorymap:
    
    pushl %eax
    pushl %ebx 

    movl multiboot_flags, %eax
    # multiboot_flags[6] bit for MMAP
    test $0x40, %eax
    jz print_no_memorymap

    movl multiboot_info_addr, %eax
    addl $MMAP_LENGTH_OFFSET, %eax
    movl (%eax), %ebx
    movl %ebx, mmap_length
    addl $4, %eax
    movl (%eax), %ebx
    movl %ebx, mmap_addr

    call print_memory_ranges

    jmp out_print_memorymap

  print_no_memorymap:
    
    movl $msg_no_memorymap, %ebx
    call print_line_until_null
    call videomem_newline

  out_print_memorymap:
    
    popl %ebx
    popl %eax 

    ret

# prints provided memory ranges from mmap_addr
print_memory_ranges:
    
    pushl %eax
    pushl %ebx
    pushl %ecx
    pushl %edx

    movl mmap_length, %eax
    shrl $2, %eax
    # contains quotinent
    movl %eax, %ecx
  
  print_range:

    # prints intro msg
    leal msg_memory_range, %ebx
    call print_line_until_null
    movl mmap_addr, %eax
    
    # CHECK IF IT IS SIZE
    movl (%eax), %ebx
    shr $2, %ebx
    subl %ebx, %ecx
    
    # print Base Address Part1
    movl 8(%eax), %ebx
    call print_number_from_register
    # print Base Address Part2
    movl 4(%eax), %ebx
    call print_number_from_register

    # print "-0x"
    leal msg_suffix0x, %ebx
    call print_line_until_null

    # print End Address Part1
    movl 8(%eax), %ebx
    movl 16(%eax), %edx
    addl %edx, %ebx
    call print_number_from_register
    # print End Address Part2
    movl 4(%eax), %ebx
    movl 12(%eax), %edx
    decl %ebx
    addl %edx, %ebx
    call print_number_from_register

    # print type
    leal msg_type, %ebx
    call print_line_until_null

    movl 20(%eax), %ebx
    call print_number_from_register
    
    call videomem_newline

    # ADD SIZE
    movl (%eax), %ebx
    addl $4, %ebx
    addl %ebx, %eax

    # Move to the next mem card
    movl %eax, mmap_addr

    loop print_range

    popl %edx
    popl %ecx
    popl %ebx
    popl %eax 

    ret

# finds RSD pointer by finding string "RSD PTR "
find_rsd_pointer:
    
    pushl %eax
    pushl %ecx

    # 1) Search in EBDA
    xorl %eax, %eax
    movw $PEBDA_START, %ax
    # EBDA START address in %eax
    movl (%eax), %eax
    # 1 KB
    movl $1024, %ecx
    # Start searching
    call find_RSD_PTR_match

    movl rsdt_ptr, %eax
    
    # Check if pointer is found in EBDA
    cmp $0, %eax
    jnz out_find_rsd_pointer

    # 2) Search in ReadOnly Memory Space
    movl $ROMEM_SPACE_START,  %eax
    movl $ROMEM_SPACE_LENGTH, %ecx
    # Start searching
    call find_RSD_PTR_match
  
  out_find_rsd_pointer:

    popl %ecx
    popl %eax

    ret 

# Looking for "RSD PTR " 
#
# @param %eax - search start address
# @param %ecx - search step  amount
find_RSD_PTR_match:
    
    pushl %eax
    pushl %ebx
    pushl %ecx

    movl $0x000E0000, %eax
    # counter
    movl $0x1FFFF, %ecx
    
  find_match:

    movl (%eax), %ebx
    
    # Match "RSD "
    cmp $0x20445352, %ebx
    jnz out_find_match
    
    addl $4, %eax
    movl (%eax), %ebx

    # Match "PTR "
    cmp $0x20525450, %ebx
    # Yep, we've got match
    jz got_match

  out_find_match:
    
    inc %eax

    loop find_match
    
    # Didn't find anything
    jmp out_find_RSD_PTR_match

    # Match is found
  got_match:
    # (!) Save rsdt_ptr
    addl $4, %eax # Skip Signature
    addl $1, %eax # Skip CheckSum
    addl $6, %eax # OEMID
    addl $1, %eax # Skip Revision
    movl (%eax), %ebx # RsdtAddress
    movl %ebx, rsdt_ptr

  out_find_RSD_PTR_match:
    
    popl %ecx
    popl %ebx
    popl %eax

    ret

# Looking through tables for MADT (Multiple APIC Description Table)
handle_rsd_table:

    pushl %eax
    pushl %ebx
    pushl %ecx

    movl rsdt_ptr, %eax
    addl $4, %eax       # Skip Signature "RSDT"
    movl (%eax), %ebx   # Length
    subl $36, %ebx      # Length - sizeof(ACPI header)
    shrl $2, %ebx       # Amount of entries
    addl $32, %eax      # Points on a first entry
    movl %ebx, %ecx     # Loop counter = Amount of entries
  
  for_all_entires:
    
    movl (%eax), %ebx   # Enrty address
    movl (%ebx), %edx   # Signature

    # signature is "APIC"
    cmp $0x43495041, %edx 
    jnz out_for_all_entires

    call handle_MADT

  out_for_all_entires:
    
    addl $4, %eax
    
    loop for_all_entires
    
    popl %ecx 
    popl %ebx
    popl %eax

    ret

# Prints information about APIC
#
# @param %ebx - contatines MADT address
handle_MADT:
    
    pushl %eax
    pushl %ebx
    pushl %ecx
    pushl %edx


    movl %ebx, madt_addr  # Saves MADT address
    movl 4(%ebx), %ecx    # MADT length
    subl $0x2C,   %ecx    # Minus ACPI header length

    movl 0x24(%ebx), %eax # Local Controller Address
    movl %eax, local_controller_address + 4
    movl 0x28(%ebx), %eax # Flags

    # Is Dual Legacy PICs installed ?
    cmp $1, %eax
    jnz dual_legacy_PICs_not
    
    leal msg_dual_supported, %ebx
    call print_line_until_null
    call videomem_newline
    jmp process_MADT_records

  dual_legacy_PICs_not:

    leal msg_dual_not_supported, %ebx
    call print_line_until_null
    call videomem_newline
  
  process_MADT_records:

    movl madt_addr, %ebx
    # Offset for APIC records
    addl $0x2C, %ebx
    xorl %eax,  %eax
  
  for_records_in_MADT:
    
    cmp $0, %ecx
    jl out_hanldle_MADT

    movb (%ebx), %al
    # Local APIC?
    cmp $0, %al
    jnz maybe_IO_APIC

    call handle_local_apic

  maybe_IO_APIC:
    cmp $1, %al
    jnz maybe_Address_Override

    call handle_IO_apic

  maybe_Address_Override:
    cmp $5, %al 
    jnz maybe_x2APIC

    call handle_addr_override_structure
  
  maybe_x2APIC:
    cmp $9, %al
    jnz out_for_records_in_MADT
    call handle_local_x2apic
  
  out_for_records_in_MADT:
    
    xorl %eax, %eax
    movb 1(%ebx), %al # Length
    subl %eax, %ecx
    addl %eax, %ebx

    jmp for_records_in_MADT

  out_hanldle_MADT:

    # prints Local APICs address msg
    leal msg_local_APICs_addr, %ebx
    call print_line_until_null

    # prints address
    leal local_controller_address, %eax
    movl (%eax), %ebx
    call print_number_from_register
    movl 4(%eax), %ebx
    call print_number_from_register

    popl %edx 
    popl %ecx
    popl %ebx
    popl %eax

    ret

# params %ebx contains current address
handle_local_apic:
    
    pushl %eax
    pushl %ebx

    leal msg_local_APIC, %ebx
    call print_line_until_null
    
    popl  %ebx
    pushl %ebx

    xorl %eax, %eax
    movb 3(%ebx), %al
    movl %eax, %ebx

    call print_number_from_register
    call videomem_newline

    popl %ebx
    popl %eax

    ret

# params %ebx contains current address
handle_IO_apic:
    
    pushl %eax
    pushl %ebx
    pushl %edx

    # Saves address
    movl %ebx, %edx

    leal msg_IO_APIC, %ebx
    call print_line_until_null

    xorl %eax, %eax
    movb 2(%edx), %al
    movl %eax, %ebx
    call print_number_from_register

    leal msg_IO_APIC_addr, %ebx
    call print_line_until_null

    # I/O APIC Address
    movl 4(%edx), %ebx
    call print_number_from_register

    leal msg_IO_APIC_irqs, %ebx
    call print_line_until_null

    # I/O APIC Address
    movl 8(%edx), %ebx
    call print_number_from_register

    call videomem_newline

    popl %edx
    popl %ebx
    popl %eax

    ret

# params %ebx contains current address
handle_local_x2apic:
    
    pushl %eax
    pushl %ebx

    leal msg_local_x2APIC, %ebx
    call print_line_until_null
    
    popl  %ebx
    pushl %ebx

    xorl %eax, %eax
    movl 4(%ebx), %eax
    movl %eax, %ebx

    call print_number_from_register
    call videomem_newline

    popl %ebx
    popl %eax

    ret
    
# params %ebx contains current address
handle_addr_override_structure:
    
    pushl %eax
    pushl %ebx
    pushl %ecx

    movl 4(%ebx), %eax
    movl 8(%ebx), %ebx

    # Saves local_controller_address
    leal local_controller_address, %ecx
    movl %ebx, (%ecx)
    movl %eax, 4(%ecx)
    
    popl %ecx
    popl %ebx
    popl %eax

    ret

#=======================================================
# Include help functions 

.include "lib.S"

#=======================================================
# Global variables

multiboot_info_addr:
    .long 0x00

multiboot_flags:
    .long 0x00

video_memory:
    .long 0xB8000

mmap_addr:
    .long 0x00

mmap_length:
    .long 0x00

rsdt_ptr:
    .long 0x00

madt_addr:
    .long 0x00

local_controller_address:
    .long 0x00
    .long 0x00

#=======================================================
# Strings

msg_cmd_line:
    .asciz "cmdline: "

msg_no_memorymap:
    .asciz "No info about memory map provided!"

msg_memory_range:
    .asciz "memory-range: 0x"

msg_suffix0x:
    .asciz "-0x"

msg_type:
    .asciz " type 0x"

hex_table:
    .asciz "0123456789ABCDEF"

msg_match:
    .asciz "RSD PTR "

msg_MADT:
    .asciz "APIC"

msg_dual_supported:
    .asciz "PC/AT dual PIC supported"

msg_dual_not_supported:
    .asciz "PC/AT dual PIC not supported"

msg_local_APIC:
    .asciz "Local APIC 0x"

msg_local_x2APIC:
    .asciz "Local x2APIC 0x"

msg_IO_APIC:
    .asciz "IOAPIC 0x"

msg_IO_APIC_addr:
    .asciz " at 0x"

msg_IO_APIC_irqs:
    .asciz " IRQs from 0x"

msg_local_APICs_addr:
    .asciz "Local APICs accessible at 0x"

#=======================================================
# Consts

.set CMDLINE_OFFSET,     0x10
.set MMAP_LENGTH_OFFSET, 44
.set MMAP_ADDR_OFFSET,   48
.set COLOR,              0x03
.set VMEM_START,         0xB8000

.set PEBDA_START,        0x40E
.set ROMEM_SPACE_START,  0xE0000
.set ROMEM_SPACE_LENGTH, 0x1FFFF

#=======================================================
# Stack

stack_bottom:
    .skip 2048
stack:

#=======================================================
# GDT

GDTR: 
GDT_lim:
    .short (GDT_end - GDT) - 1
GDT_adr:        
    .long GDT

GDT:

# NULL_DESCRIPTOR (never referenced)
# CODE_DESCRIPTOR
# DATA_DESCRIPTOR
# STACK_DESCRIPTOR
# |    Part 1     |                              |      ACCESS RIGHTS     |Part 2|        | 
# [Address(31-24) ; G ; D ; X ; U ; Limit(19-16) ; P ; DPL ; S ; Type ; A ; Address(23-0) ; Limit(15-0)]
# 63           56  55  54  53  52   51        48  47  46 45 44   43 41 40   39         16   15        0

    # NULL_DESCRIPTOR
    .quad 0x00
    # Descriptor for CS
    .byte 0xFF # Limit
    .byte 0xFF # Limit 
    .byte 0x00 # Address 
    .byte 0x00 # Address
    .byte 0x00 # Address
    .byte 0x9E # 10011110b P = 1 DPL = 00 S = 1 Type = 111 A = 0
    .byte 0xDF # 11001111b G = 1 D = 1 
    .byte 0x00 # Address
     
     # Descriptor for DS
    .byte 0xFF 
    .byte 0xFF 
    .byte 0x00 
    .byte 0x00 
    .byte 0x00 
    .byte 0x92 #10010010b P = 1 DPL = 00 S = 1 Type = 001 A = 0
    .byte 0xDF #11001111b G = 1 D = 1 
    .byte 0x00 

# P ; DPL ; S ; Type ; A ;
# P    = 1b   Segment presence in memory
# DPL  = 00b  Descriptor Privelege Level (00b for 0 system level)
# S    = 1b   System object (1b for Code segment or Data segment)
# Type = 111b Segment Type
# A    = 0b   Access bit 

GDT_end:

#=======================================================
# IDT

IDTR: 

IDT_lim:
    .short (IDT_end - IDT) - 1
IDT_adr:        
    .long IDT

IDT:
    .rept 0x20
    .quad 0x00
    .endr

PIC_IRQs:
    # Offset Low
    .short 0x00 
    .short 0x08
    .byte  0x00
    .byte  0x8E
    # Offset High
    .short 0x00
    .rept 0x20
    .quad 0x00
    .endr

IDT_end: