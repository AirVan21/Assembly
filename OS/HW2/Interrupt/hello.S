    .code32    

    .section .multiboot
    # Align 4 byte boundary 
    .align  4
    # MULTIBOOT_HEADER_MAGIC 
    .long 0x1BADB002
    # MULTIBOOT_HEADER_FLAGS
    .long 0x00000000
    # Checksum 
    .long -(0x1BADB002 + 0x00000000)

    .text
    .globl _start

# Global Entry Point
_start:

    # JUMPS to a code start
    jmp main

# GLOBAL:
# EBX containes amount of interrupt occasions
# CH  containes id of COLOR 
print:
    inc %ebx 
    
    # (1.193182 MHz / 0xFFFF) = 18 
    cmp $18, %ebx

    jne outPrint
    
    # Change color (GREEN <==> BLUE) 
    xorb $0x01, %ch
    
    # Video memory offset
    movl $0xB8000, %edx
    
    # AL = Character AH = Color (Takes COLOR FROM CH)
    # Print in Video Memory | edx contains pointer
    movb $'t', %al
    movb %ch, %ah
    movw %ax, (%edx)
    add  $0x02, %edx
    movb $'i', %al
    movw %ax, (%edx)
    movb $'c', %al
    add  $0x02, %edx
    movw %ax, (%edx)
    movb $'k', %al
    add  $0x02, %edx
    movw %ax, (%edx)
    
    # Clears accumulator for timer tick 
    xor %ebx, %ebx

outPrint:
    # Wake up timer
    mov $0x20, %al
    out %al, $0x20 

    iret

main:
    # Interrupts are disabled until OS sets up its own IDT. (c)

    # Sets GDT 
    lgdt GDTR
    # Far jmp CODE_SELECTOR : CodeWithOwnGDT
    ljmp $0x08, $CodeWithOwnGDT 

CodeWithOwnGDT:

    # DATA_SELECTOR
    mov $0x10, %ax
    mov %ax, %ds
    # STACK_SELECTOR
    mov %ax, %ss
    # Init ESP with stack: 
    movl $stack, %esp

    lidt IDTR

    # Remaps PICs
    movb $0x11, %al 
    out %al, $0x20     # Restart PIC1
    out %al, $0xA0     # Restart PIC2

    movb $0x20, %al 
    out %al, $0x21     # PIC1 now starts at 0x20
    movb $0x28, %al 
    out %al, $0xA1     # PIC2 now starts at 0x28

    movb $0x04, %al    # Setup cascading
    out %al, $0x21
    movb $0x02, %al
    out %al, $0xA1

    movb $0x01, %al
    out %al, $0x21
    out %al, $0xA1

    # Setting handler for IRQ 0 (System time)
    leal print, %eax
    mov %ax, PIC_IRQs
    shr $16, %eax
    mov %ax, (PIC_IRQs + 6)

    # Disable all IRQs except 0-th
    in  $0x21, %ax 
    mov $0xFE, %ax
    out %ax, $0x21

    # Setting clock rate
    movb $0x34, %al      # channel 0, lobyte/hibyte, rate generator
    out  %al, $0x43
 
    mov  $0xFFFF, %ax    # AX = 16 bit reload value
    out  %al, $0x40      # Set low byte of PIT reload value
    movb %ah, %al        
    out  %al, $0x40      # Set high byte of PIT reload value

    # Color for print   | Will be a global param
    movb $2, %ch
    # Interrupt counter | Will be a global param
    xor %ebx, %ebx
    
    sti 

deadloop:
    jmp deadloop

stack_bottom:
    .skip 1024
stack:

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