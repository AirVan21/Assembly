	CSEG segment
	
	org 100h

begin:
	
	mov ah, 9h
	lea dx, msg
	int 21h

	int 20h

msg db 'Hello, world!', 13, 10, '$'

	CSEG ends

end begin