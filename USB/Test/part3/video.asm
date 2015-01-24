CSEG segment
org 100h

; display segment in text mode
dispSeg = 0B800h 

start:

	mov ax, dispSeg
	mov es, ax 
	; displacement from video mem
	mov di, 0h
	; white symbol, blue background
	mov ah, 31 
	; strange symbol
	mov al, 1

	; writing to video mem
	mov es:[di], ax


	; wait input 
	mov ah, 10h
	int 16h

	; out of program
	int 20h

CSEG ends
end start