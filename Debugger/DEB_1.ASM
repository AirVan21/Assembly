	model tiny
	.486
	.code
	org 100h

psp = ((stop - _ + 100h)+15)/16*16; calculating size
				  ; / 16 = > get paragraphs
prog = psp+100h                   ; all links got offset = 100h, use it

_:	
	jmp start

fname   db 'hw1.com',0
errmsg  db 'Error!',13,10,'$'
okmsg   db 'File loaded successfully!',13,10,'$'
byemsg  db 'Finished trace',13,10,'$'
sym_tab db '0123456789ABCDEF'
newstr  db ' ',13,10,'$'
semicol db ':$'
vector  dd 0

start:
	mov ah, 03Dh  ; 'open file' function
	xor al, al    ; read only mode
	mov dx, offset fname; pointer to file name, file in local directory
	int 21h       ; MSDOS call
	
	jc err_	      ; if CF is set => Error

		      ; got file handle (or error code) in ax after 'file open'
	mov bx, ax    ; saves file handel in bx
	mov ah, 03Fh  ; 'read file' function
	mov cx, 0FFFFh; number of bytes to read
	mov dx, prog  ; buffer adress
	int 21h;

	jc err_
	
	mov ah, 9     ; 'print string' function
	mov dx, offset okmsg; put 'ok' 
	int 21h       ; show right load
	
	mov ah, 03Eh  ; 'close file handle' function
	int 21h       ;
	
	jc err_       
	
	mov ax, psp/16; calc size of program in paragraphs
	push cs       ; put on stack current segment (cs:ip)
	pop bx        ; segment in bx
	add ax, bx    ; in ax - code segment after current program
	
	mov bx, psp   ; in bx size in bytes
	mov byte ptr[bx], 0CBh; retf = 0CBh, for correct return in parent 
	
	push ax       ; save
	push bx        ;
	push es        ;
	
	mov ax, 3501h          ;'get interrupt vector'
	int 21h                ; pointers on vecotr in bx, es
	mov word ptr vector, bx; saves information
	mov word ptr vector, es;
	pop es
	pop bx	

	mov dx, offset printer; place to be after int 1, 35h -> read old vector
	mov ax, 2501h ; handling int 1
	int 21h       ; sets int 1 handler 
	
	pop ax	      ; recover AX

	push cs       ; CS (save for correct return) 
	push offset eod_handler ; IP - replace here after return
		      ; retf pushes IP; CS
	mov ds, ax    ; fix ds for loaded program
	push 0        ; for ret(IP) in loaded  => to place, were 0CBh
	pushf         ; gets flag register
	pop bx        ; puts flags in bx
	or bx, 100h   ; sets TF flag
	push bx       ; new flag register
	push ax       ; segment for loaded program
	push 100h     ; IP for loaded program
 
	iret	      ; jump to loaded program code
	
	ret

eod_handler:          ; will be here after trace end 
	push cs       ; 
	pop ds        ; correct ds
	
	pushf         ; get flag regitser
	pop bx        ; eflags in bx - FIX
	xor bx, 100h  ; turn off TF
	push bx       ; new flag on stack
	popf          ;
	
	push ax
	push dx 

	mov dx, offset byemsg;
	mov ah, 9     
	int 21h
	
	lds dx, vector; pointer to old int 1 vector
	mov ax, 2501h ; recover old vector
	int 21h       ;
	
	pop dx
	pop ax

	ret		

printer: 
	push bp       ;
	mov bp, sp    ; SP in BP
	
	push ds       ; save
	push cs       ;
	pop ds        ; set ds == cs from loaded program

	push cx       ; save all registers in stack
	push bx
	push dx
	push ax
	
	mov bx, offset sym_tab; pointer to translation table
	
	mov cx, [bp + 4]      ; gets CS from stack (CS to print)
	mov ax, cx; 
	shr ax, 12            ; print first letter
	xlat                  ; translates char, puts in AL
	mov dl, al            ; result
	mov ah, 02            ; 'print char'
	int 21h   
	
	mov ax, cx
	shr ax, 8
	and al, 0Fh; take last char
	xlat
	mov dl, al
	mov ah, 02
	int 21h

	mov ax, cx
	shr ax, 4
	and al, 0Fh; take last char
	xlat
	mov dl, al
	mov ah, 02
	int 21h

	mov ax, cx
	and ax, 0Fh; take last char
	xlat
	mov dl, al
	mov ah, 02
	int 21h

	mov dx, offset semicol; 'print char' semicol
	mov ah, 9
	int 21h
	
	mov cx, [bp + 2]      ; gets IP from stack  (IP to print)
	mov ax, cx; 
	shr ax, 12            ; print first letter
	xlat                  ; translates char, puts in AL
	mov dl, al            ; result
	mov ah, 02            ; 'print char'
	int 21h   
	
	mov ax, cx
	shr ax, 8
	and al, 0Fh; take last char
	xlat
	mov dl, al
	mov ah, 02
	int 21h

	mov ax, cx
	shr ax, 4
	and al, 0Fh; take last char
	xlat
	mov dl, al
	mov ah, 02
	int 21h

	mov ax, cx
	and ax, 0Fh; take last char
	xlat
	mov dl, al
	mov ah, 02
	int 21h

	mov dx, offset newstr; go to the new string
	mov ah, 9
	int 21h
	
	pop ax       ; recover all registers	
	pop dx
	pop bx
	pop cx
	pop ds
	pop bp
	iret	
err_:
	mov ah, 9     	     ; 'string output' function
	mov dx, offset errmsg; string adress
	int 21h              ; MSDOS call
	ret
stop:                        ; label for program length calculating
	end _	