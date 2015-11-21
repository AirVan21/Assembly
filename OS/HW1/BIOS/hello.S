	# Abramov

	.code16
	.text
	.global _start

	# Global Entry Point
_start:

    movw %cs, %ax
    movw %ax, %ss
    mov $stack, %ax 
    mov %ax, %sp
	jmp main

print:
	
	# Teletype output via 'int 10h' : AL = Character, BH = Page Number, BL = Color (only in graphic mode)
	movb $0x0E, %ah
	# Call BIOS 'int 10h'
	int  $0x10
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

deadloop:
	jmp deadloop

.space 100
stack:

. = _start + 0x1FE # To the end of boot sector (510-th byte)
	.byte 0x55     # Boot Magic
	.byte 0xAA     # Boot Magic
