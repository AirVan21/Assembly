	model tiny
	.CODE
	.486p
	org 100h          		 ;  Going to create .COM file

_:

	jmp start  ;  Marker to place, where program starts	

; INT CONSTS
CMOS_PORT_ID   = 70h         ; Port for CMOS memory access	
CODE_DESC_OFFS = 08h         ; Code Descriptor Offset
DATA_DESC_OFFS = 10h         ; Data Descriptor Offset
STACK_BASE     = 1024*1024*5 ; 
VIDEO_BASE     = 0B8000h     ; Video memory for color monitors

USB1_BAR       = 0C360A0000h ; BAR from 1-st device 
USB2_BAR       = 0C36090000h ; BAR from 2-nd device

start:

set_prot_mode:

	call disable_interrupts   		; Disable Maskable && Non-Maskable interrupts
	call setGDTpar           		; Calculate GDT size
	mov edi, dword ptr [GDTR]		; Load argument
	lgdt [edi]               		;  
	call CODE_DESC_OFFS:switchToPm  ; Setting in CS register Code Selector  
	call enable_interrupts          ; Enable Maskable && Non-Maskable interrupts
	jmp outOfProg                   ; End program

switchToPm:
	mov ax, DATA_DESC_OFFS          ; Setting Data Selector
	mov ds, ax                      ; 
	mov es, ax                      ; Selector of Data Segment
	mov ss, ax                      ; Figure out problems with stack! 
	mov esp, STACK_BASE             ;  	
	ret

setGDTpar:
	xor eax, eax             		;
	push bx                  		; Save bx
	mov ax, ds               		; Segment addr
	shl eax, 4               		; Segment*16
	lea bx, GDT              		; Offset
	add ax, bx               		; Linear Address calc
	mov dword ptr [(GDTR+2)], eax           ; Setting Address  
	pop bx                   		; Recover bx
	ret                      		;

; Simple Video Mem Case
printPMGreating:
	push edi                 ; Saves edi
	push bx                  ; Saves bx
	push ax                  ;
	mov edi, VIDEO_BASE      ; Pointer to Video Mem 
	mov bl, 05h              ; Print Style
	
	mov al, 'P'
	mov [edi], al          
	mov [edi+1], bl           

	mov al, 'M'
	mov [edi+2], al                     
	mov [edi+3], bl          
          
	pop edi                  ; Recover
	pop bx                   ;
	pop ax                   ;
	ret

     

; Disables Maskable && Non-Maskable interrupts
disable_interrupts:
	xor eax, eax         ;
	push dx              ; Save dx
	xor dx, dx           ;
	cli                  ; Blocking Maskable Interrupts
	mov dx, CMOS_PORT_ID ; (Params should be registers)
	in  al, dx           ; Getting CMOS-byte
	or  al, 80h          ; First bit for Non-Maskable
	                     ; 0 - Enabled, 1 - Disables
	out dx, al           ; Disabling NMI 
	pop dx               ; Recover dx
	ret                  ;

; Enables Maskable && Non-Maskable interrupts
enable_interrupts:
	xor eax, eax         ;
	push dx              ; Save dx
	xor dx, dx           ;
	mov dx, CMOS_PORT_ID ; 
	in  al, dx           ; Getting CMOS-byte
	and al, 7Fh          ; Setting first bit to zero 
	                     ; 0 - Enables NMI
	out dx, al           ;
	pop dx               ; Recover dx
	sti                  ; Enable Maskable interrupt
	ret                  ;


; The main Global Descriptors Table (GDT), 8192 records 
GDT_COUNT = 8192

GDT:
NULL_descr	db 0,0,0,0,0,0,0,0									; null descriptor (never referenced)
CODE_descr	db 0FFh,0FFh,00h,00H,00H,10011010b, 11001111b,00h	; 1 code main code descriptor (kernel)
DATA_descr	db 0FFh, 0FFh, 00h, 00h, 00h, 10010010b, 11001111b, 00h	; 2 data main descriptor
GDT_16bitCS	db 0FFh, 0FFh, 0, 0, 0, 10011010b, 0, 0			    ; 3 16-bit code descriptor
GDT_16bitDS	db 0FFh, 0FFh, 0, 0, 0, 10010010b, 0, 0		        ; 4 16-bit data descriptor

gdt_free_cells         db (GDT_COUNT-1-5) DUP (6 DUP(0))        ; Setting zeros for (5-8191 records)	

GDT_DESCR:

GDT_size = (GDT_DESCR - GDT)
GDTR	dw (GDT_size-1) 
		dd 0h

TERMINATE db 0CDh, 20h

outOfProg:
	jmp outOfProg            		;
	
	ret
	end _