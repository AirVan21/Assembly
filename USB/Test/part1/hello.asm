	model tiny
	.386
	.code
	org 100h 
_:

jmp start

	msg db 'Hello, world!', 13, 10, '$'

start:

	; Clear ah
	xor ah, ah
	; Pointer of string to print
	lea dx, msg
	; Number of print function
	mov ah, 09h	
	
	; Call print function
	int 21h	
	; Jump to CD20
	ret
end _