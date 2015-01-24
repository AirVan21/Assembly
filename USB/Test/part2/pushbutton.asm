CSEG segment
org 100h

start:

	mov ah, 09h
	lea dx, msg
	int 21h

	mov ah, 10h ; For keaboard read
	int 16h     ; BIOS interrupt

	int 20h     ; CD20
	
msg db 'Push the button', 13, 10, '$'
	
CSEG ends
end start