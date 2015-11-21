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
    
    # Init stack pointer 
    movl $stack, %esp
    # Reset FLAGS register
    pushl $0
    popf
    # Pushes the pointer to the Multiboot information structure
    pushl %ebx
    # Pushes the magic value.
    pushl %eax
    # Pointer to Video Mem
    movl $0xB8000, %edx
    
    jmp main

print:
	
	# AL = Character AH = Color (GREEEEEN)
	movb $0x02, %ah
    # Print in Video Memory | ecx contains pointer
    movw %ax, (%edx)
    add  $0x02, %edx 
	ret

main:

    mov $'H', %al 
    call print

	mov $'e', %al 
    call print
    
    movb $'l', %al
    call print

    movb $'l', %al
    call print

    movb $'o', %al
    call print
    
    movb $',', %al
    call print

    movb $' ', %al
    call print

    movb $'W', %al
    call print

    movb $'o', %al
    call print

    movb $'r', %al
    call print

    movb $'l', %al
    call print

    movb $'d', %al
    call print

    movb $'!', %al
    call print

    # just clear screen loop 
    movl $0x250, %ecx

clrscr:
    movb $' ', %al
    call print
    loop clrscr

deadloop:
    jmp deadloop

stack_bottom:
.skip 1024
stack:

