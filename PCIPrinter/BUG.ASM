	model tiny
	.code
	.386
	org 100h
	
_:	jmp start

change     db ' | $'
newstr     db '',13,10,'$'
file       db 'name.txt',0
msg 	   db 'Bye PCI printer!',13,10,'$'
hex_table  db '0123456789ABCDEF'
pathBase   db 'FSTREE',0
vendir     db '     ', 0
end1       db '$'
devdir     db '     ',0
end2       db '$'
datadir    db '        $'
filename   db 'name.txt', 0
readdata   db ' '

start: 
	mov ecx, 80000000h ; data + adress
	          
_c:	
	xor si, si         ; Counter for data field
	mov eax, ecx       ; out works with eax
	mov dx, 0CF8h      ; Config_Adress for access	
	out dx, eax        ; sends data to port
	add dx, 4          ; 0CFC - Config_Data 	
	in eax, dx         ; Gets data from defined 80000000h adress
	
	sub dx, 4          ; set port 0CF8h
	cmp ax, -1         ; Vendor ID == FFFF => invalid value
	je _devstep        ; 

	mov edi, eax       ; Save original value in EDI
	lea bx, hex_table  ; Translate table
	shr eax, 28        ; Last 4 bits
	xlat               ; Perform translation	

	lea bx, datadir    ; path storrage adress  
			   ; Saves char for future directory search
	mov [bx + si], al  ; 
	;__________________ 
	
	push ecx
	xor ecx, ecx       ;
	mov cx, 24         ; Loop counter
cycle:	
	mov eax, edi       ; Saved original value from EDI => EAX
	shr eax, cl        ; Last 4 bit
	and al, 0Fh        ;  
	lea bx, hex_table  ;
	xlat               ; Perform translation	

	lea bx, datadir    ; Storrage adress
	add si, 1          ; Place 4 next symbol
	mov [bx+si], al    ; Save current symbol 
	sub cx, 3          ; -2 for counter
	loop cycle         ;
	;__________________ 

	mov eax, edi       ;
	and al, 0Fh        ; in AL only last 4 bits
	lea bx, hex_table  ; 
	xlat               ; Translation
	lea bx, datadir    ; Storrage adress
	inc si             ; Place for next symbol in storrage
	mov [bx + si], al       ; Saves symbol
	
			   ; Saves vendorID & deviceID in EDI

	call writepath     ; Writes path for 

	lea dx, change     ;
	mov ah, 9h         ; print ' : '
	int 21h            ;
	
	pop ecx            ; Reset counter
	
	mov eax, ecx       ; print bus
	mov bx, offset hex_table;
	shr eax, 19        ;
	and al, 0Fh        ;
	xlat               ; Translates
	mov dl, al	   ;
	mov ah, 02h        ;  
	int 21h            ; 

	mov eax, ecx       ; print bus
	mov bx, offset hex_table;
	shr eax, 15        ;
	and al, 0Fh        ;
	xlat               ; Translates
	mov dl, al	   ;
	mov ah, 02h        ;  
	int 21h            ; 

	mov dl, ' '        ; ' ' between bus and device
	int 21h            ;
	
	mov eax, ecx       ; print device
	mov bx, offset hex_table;
	shr eax, 11        ;
	and al, 0Fh        ;
	xlat               ; Translates
	mov dl, al	   ;
	mov ah, 02h        ;  
	int 21h            ; 
	
	mov eax, ecx       ; print device
	mov bx, offset hex_table;
	shr eax, 8         ;
	and al, 0Fh        ;
	xlat               ; Translates
	mov dl, al	   ;
	mov ah, 02h        ;  
	int 21h            ; 
	

	mov ah, 9h         ; CRLF
	lea dx, newstr     ;
	int 21h            ; 

	   
	call descript      ; Prints extra info     

	mov eax, ecx	   ; add HEADERTYPE  displacement
	add eax, 0Ch       ; 
	mov dx, 0CF8h      ;
	out dx, eax        ; send adress & data
	add dx, 4          ; get 0CFC;
	in eax, dx         ;
	shr eax, 17h       ; last bit == MF flag
	test al, 1h        ; zero OR one
	jnz _funstep       ; in MF == true => watch functions
         	
_devstep:
	and ecx, 0FFFFF800h;
	add ecx, 800h      ; Move to the next device
	test ecx,1000000h  ; Logical AND for flag set
	jz _c
	jmp _out;

_funstep:	
	add ecx, 100h      ;
	test ecx,1000000h  ;
	jz _c              ; 	
	
writepath:
	pusha              ; Saves all registers 
	mov cx, 4          ; Counter for 4 symbols
	xor si, si         ;
	xor ax, ax         ;
cycdev:                    ; Write vendir from datadir
	lea bx, datadir    ;
	mov al, [bx + si]  ; Gets symbol
	inc si             ; Increase counter	
	lea bx, devdir     ; Adress of recipient
	mov [bx + si], al  ;
	loop cycdev        ;

	mov cx, 4          ;
	push di            ;
	xor di, di         ;
cycven:
	lea bx, datadir    ;
	mov al, [bx + si]  ; Gets symbol
	inc si             ; Increase counter	
	inc di             ;
	lea bx, vendir     ; Adress of recipient
	mov [bx + di], al  ;
	loop cycven        ;
	
	pop di             ; Print vendor id
	lea dx, vendir     ; 
	mov ah, 9          ; 
	int 21h            ;

	mov dx, ' '        ; Print space
	mov ah, 2          ;
	int 21h            ;

	lea dx, devdir     ; Print device id
	mov ah, 9h         ;
	int 21h            ;
	popa               ; Recover all registers
	ret                ;

descript:
	pusha              ; Save all registers
	mov ah, 3Bh        ; In base!
	lea dx, pathBase   ;
	int 21h            ;	

	mov ah, 3Bh        ; Change dir
	lea dx, vendir+1   ; Mov to vendor catalog
	int 21h            ;
	
	mov ah, 3Bh        ;
	lea dx, devdir+1   ; Mov to device catalog 
	int 21h            ; 
	
	mov ah, 3Dh        ;
	lea dx, file       ; Adress of file name
	int 21h            ;
 	
	mov bx, ax         ; Sets file handle
	mov ah, 3Fh        ; Read file
	mov cx, 100        ; Bytes to read
	lea dx, readdata   ; Buffer address
	int 21h            ;

	mov ah, 3Eh        ; Close file
	int 21h            ;

	mov ah, 9          ; PCI device name
	lea dx, readdata   ;
	int 21h            ;

	popa               ; Recover info
	ret                ;
_out:	
	mov ah, 9;
	mov dx, offset msg ; 'Goodbye!'
	int 21h
	ret
	end _
	