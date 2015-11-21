    .code32

    .text
    # Align 4 byte boundary 
    .align  4
    # MULTIBOOT_HEADER_MAGIC 
    .long 0x1BADB002
    # MULTIBOOT_HEADER_FLAGS
    .long 0x00000000
    # Checksum 
    .long -(0x1BADB002 + 0x00000000)
    .globl _start

# Global Entry Point
_start:

    # JUMPS to a code start
    jmp main

# Clears screen
clrscr:
    # Video-Mem
    movl $0xB8000, %edx
    # 
    movl $0x650,   %ecx
    xor %eax, %eax
    movb $' ',%al
    movb $0,  %ah
  
  putspace:
    movw %ax, (%edx)
    add $2, %edx
    loop putspace

    ret

# COM port initialization
init_com_port:

    xor %eax, %eax
    xor %edx, %edx

    movb $0x00, %al        # Disable all interrupts
    movw $COM_PORT+1, %dx
    outb %al, %dx

    movb $0x80, %al         # Enable DLAB (set baud rate divisor)
    movw $COM_PORT+3, %dx
    outb %al, %dx
    
    movb $0x03, %al         # Set divisor to 3 (lo byte) 38400 baud
    movw $COM_PORT, %dx
    outb %al, %dx
    
    movb $0x00, %al         #  (hi byte)
    movw $COM_PORT+1, %dx
    outb %al, %dx

    movb $0x03, %al         #  (8 bits, no parity, one stop bit)
    movw $COM_PORT+3, %dx
    outb %al, %dx

    movb $0xC7, %al         #  Enable FIFO, clear them, with 14-byte threshold
    movw $COM_PORT+2, %dx
    outb %al, %dx
    
    movb $0x0B, %al         #  IRQs enabled
    movw $COM_PORT+4, %dx
    outb %al, %dx

    ret

read_task:

    xorl %eax, %eax
    xorl %edx, %edx

    movw $COM_PORT+5, %dx
    in %dx, %al
    
    testb $0x1, %al
    jz read_task

    xor %edx, %edx
    movw $COM_PORT, %dx
    # Char in %al
    in %dx, %al
    # Color in %ah
    movb $7, %ah

    # Find place in buffer for reading
    movl write_place, %esi
    movw %ax, (%esi)
    addl $2, %esi
    movl %esi, write_place

    #call pass_task
    jmp read_task

print_task:

    xorl %eax, %eax
    xorl %ebx, %ebx
    
    movl read_place, %eax
    movw (%eax), %bx

    # Check: if we have something to read?
    cmp $0, %bl
    # nothing
    jz print_task

    # have something
    movl video_memory, %esi
    addl $2, %esi
    movw %bx, (%esi)
    movl %esi, video_memory
    
    addl $2, %eax
    movl %eax, read_place

    jmp print_task

# Adding task to task_table
#
# @param eax - contains address of a task
# @param ebx - stack size
add_task:

    # save eflags
    pushfl

    cli

    pushl %ebx
    pushl %eax
    
    movl last_task, %eax
    # check if this task is valid (last dword in task)
    movl 44(%eax), %ebx
    cmp $0, %ebx
    jz is_empty
    # moving to the next task    (task length = 48)
    add $48, %eax
    movl %eax, last_task

  is_empty:

    # address of a task
    popl %ebx
    # write address to task ip (ip field has offset 32)
    movl %ebx, EIP_OFF(%eax)
    # mark task as "valid"     (last dword in task for valid or not)
    movl %ebx, 44(%eax)
    
    # enable interrupt flag in eflags
    movl 0x20, %ebx
    movl %ebx, 36(%eax)
    
    # save cs
    xorl %ebx, %ebx
    movw %cs, %bx
    movl %ebx, 40(%eax)

    # find correct stack place for task
    movl last_stack, %ebx
    movl %ebx, 24(%eax)
    # mov stack_size in %eax
    popl %eax
    addl %eax, %ebx
    movl %ebx, last_stack

    # enable flags if they were on
    popl %ebx
    testl 0x20, %ebx
    jz out_add_task

    sti

  out_add_task:

    ret


pass_task:

    pushfl
    xorl %ebx, %ebx
    mov %cs, %bx
    pushl %ebx

    cli
    # Set flag, that we are from pass_task
    movl $1, %eax
    movl %eax, from_pass
    
    call scheduler

    ret

scheduler:

    # We were interrupted from the task 
    # Saves registers
    pushl %eax
    pushl %ebx

    xorl %ebx, %ebx

    # Store task registers
    movl current_task, %eax
    
    movl 12(%esp), %ebx
    movl %ebx, 40(%eax)      # cs
    
    movl 16(%esp), %ebx
    movl %ebx, 36(%eax)      # eflag
    
    movl 8(%esp), %ebx
    movl %ebx, 32(%eax)      # eip
    
    movl %ebp, 28(%eax)      # ebp
    movl %edi, 20(%eax)      # edi 
    movl %esi, 16(%eax)      # esi 
    movl %edx, 12(%eax)      # edx 
    movl %ecx, 8(%eax)       # ecx
    
    movl (%esp), %ebx
    movl %ebx, 4(%eax)       # ebx
   
    movl 4(%esp), %ebx
    movl %ebx, (%eax)        # eax

    movl %esp, %ebx          #
    addl $20, %ebx           #
    movl %ebx, 24(%eax)      # correct stack for task

    # If task is     valid => perform task
    #         is not valid => start from the beginning of a task queue
    
  if_valid:
  
    movl current_task, %eax
    addl $48, %eax
    movl %eax, current_task
    movl 44(%eax), %ebx
    
    cmp $0, %ebx
    jnz is_valid

    # try next task 
    movl EIP_OFF(%eax), %ebx
    cmp $0, %ebx
    jnz if_valid
    
    # take first task from task_table
    leal task_table, %eax
    movl %eax, current_task

  is_valid:

    # esp 
    movl 24(%eax), %esp
    
    # eflags
    movl 36(%eax), %ebx
    push %ebx
    
    # cs
    movl 40(%eax), %ebx
    pushl %ebx
    
    # eip
    movl EIP_OFF(%eax), %ebx
    pushl %ebx
    
    movl 4(%eax),  %ebx
    movl 8(%eax),  %ecx
    movl 12(%eax), %edx
    movl 16(%eax), %esi
    movl 20(%eax), %edi
    movl 28(%ebx), %ebp
    
    # Check if we from pass_task or from interrupt 
    movl from_pass, %eax
    cmp $0, %eax
    jnz skip_ack_timer

    # Yep, we are from interrupt
    # Wake up timer
    movb $0x20, %al
    outb %al, $0x20
    jmp out_sheduler

  skip_ack_timer:
    # zero flag which indicates that were are not from interrupt
    xorl %eax, %eax
    movl %eax, from_pass

  out_sheduler:
    # recover %eax 
    movl current_task, %eax
    movl (%eax), %eax
    
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
    leal scheduler, %eax
    mov %ax, PIC_IRQs
    shr $16, %eax
    mov %ax, (PIC_IRQs + 6)

    # Disable all IRQs except 0-th
    in  $0x21, %ax 
    mov $0xFE, %ax
    out %ax, $0x21

    # Setting clock rate
    movb $0x34, %al      # Channel 0, Rate Generator
    out  %al, $0x43
 
    mov  $0x2EE0, %ax    # 1/100 of a second
    out  %al, $0x40      # Set low byte of PIT reload value
    movb %ah, %al        
    out  %al, $0x40      # Set high byte of PIT reload value

#=======================================================
# Part with multitasling 

    call clrscr

    call init_com_port

    leal read_task, %eax
    movl $0x200, %ebx
    call add_task

    leal print_task, %eax
    movl $0x200, %ebx
    call add_task

    sti 

    # Call first task
    leal task_table, %eax
    call EIP_OFF(%eax)

#=======================================================
# Useful  consts

.set COM_PORT,   0x03F8
.set EIP_OFF,    32
.set STACK_SIZE, 0x200

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

# gvariable for writing
write_place:
    .long memory_buffer

# gvariable for reading
read_place:
    .long memory_buffer

# gvariable for reading
video_memory:
    .long 0xB8000

# gvariable for monitoring current task
current_task:
    .long task_table

# gvariable for adding tasks 
last_task:
    .long task_table

# gvariable for adding tasks 
last_stack:
    .long stack_table

# gvariable which indicates that we from pass 
from_pass:
    .long 0x00

task_table:

    # Maximum = 64 records
    .rept 0x40
    
    .long  0x00 # eax   0
    .long  0x00 # ebx   4
    .long  0x00 # ecx   8
    .long  0x00 # edx   12
    .long  0x00 # esi   16
    .long  0x00 # edi   20
    .long  0x00 # esp   24
    .long  0x00 # ebp   28
    .long  0x00 # eip   32
    .long  0x00 # eflag 36
    .long  0x00 # cs    40
    .long  0x00 # next task valid | 0 is not valid
                #                 | nonzero - valid
    .endr

stack_table:

    # Stack for 64 tasks
    .rept 0x40
    
    .rept 0x80
    .long 0x00
    .endr
    
    .endr

memory_buffer:
    .rept 8096
    .word 0x00
    .endr