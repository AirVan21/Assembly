	model tiny
	.code
	.386
	org 100h
_:	jmp start
 	
msg     db ' Bye, printer!', 13, 10,'$'
sym     db '0123456789ABCDEF'

	db 0EAh	 
f16     db 0

deal :
	cmp ah, 1     ; 'Esc check'
	je escape     ; 
	call print    ;
	ret 

escape:
	mov cs:f16, 1; Esc found
	ret          ;

print:
	pusha          ; save registers
	push ds	       
	push es
	
	push cs
	pop ds         ; ds = cs
	push cs      
	pop es         ; es = cd
	
	mov si, ax     ; save CHAR data
	
	lea bx, sym    ; translation table
	shr ax, 12     ; 4-bit translation
	xlat  
	
	mov ah, 0Eh    ; Teletype for scroll
	int 10h    	
	
	xor bh, bh     ; Get cursor position
	mov ah, 3      ;
	int 10h        ;
	
	dec dl         ; Retype
	mov ah, 2      ; Set cursor position
	int 10h        ;

	mov ah, 0Ah;   ; write char at cursor
	xor bx, bx;    ; clear page
	mov cx, 1      ; amount
	int 10h        

	xor bh,bh      ; clear page
	mov ah, 3      ; get cursor param
	int 10h
	
	add dl, 1      ; step to the next column
	mov ah, 2      ; set cursor param
	int 10h
;   ____________________________________________
	
	mov ax, si     ; source
	shr ax, 8      ; 
	and ax, 0Fh    ; 
 	lea bx, sym    ; table
	xlat           ;
	
	mov ah, 0Ah;   ; write char at cursor
	xor bh, bh;    ; clear page
	mov cx, 1      ; one symbol
	int 10h        

	xor bh,bh      ; clear page
	mov ah, 3      ; get cursor param
	int 10h
	
	add dl, 2      ; step to the next column
	mov ah, 2      ; set cursor param
	int 10h
;   ____________________________________________

	mov al, '-'    ;
	mov ah, 0Ah;   ; write char at cursor
	xor bh, bh;    ; clear page
	mov cx, 1      ; one symbol
	int 10h        

	xor bh,bh      ; clear page
	mov ah, 3      ; get cursor param
	int 10h
	
	add dl, 2      ; step to the next column
	mov ah, 2      ; set cursor param
	int 10h
;   ____________________________________________
	
	mov ax, si     ; source
	
	mov ah, 0Ah;   ; write char at cursor
	xor bx, bx;    ; clear page
	mov cx, 1      ; amount
	int 10h        

	xor bh,bh      ; clear page
	mov ah, 3      ; get cursor param
	int 10h
	
	mov dl, 0      ; step to the next column
	add dh, 1      ; step to the next row
	mov ah, 2      ; set cursor param
	int 10h
	
;   ____________________________________________
	
	pop es
	pop ds
	popa
	ret
start:	
	; Printing char with int16
	
keytest:
	xor ax, ax    ; ah == 0 for KBD read
	int 16h	      ; KBD service
	call deal     ; print char or escape 
	cmp cs:f16, 1 ; 'Esc == 1' => for escape
	jne keytest   ; 
	
	;Print 'Bye!'
	mov ah, 9     
	mov dx, offset msg
	int 21h       
 
	ret           
	
	end _