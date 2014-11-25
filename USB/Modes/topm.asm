	model tiny
	.CODE
	.486p
	org 100h          ;  Going to create .COM file

_:

; CONSTS
CMOS_PORT_ID   = 70h    ; Port for CMOS memory access	

	jmp start  ;  Marker to place, where program starts	
	
start:

set_prot_mode:
	
	call enable_interrupts   ; Disable Maskable && Non-Maskable interrupts
	call setGDTpar           ; Calculate GDT size
	lgdt GDTR                ;  
	jmp outOfProg            ;
	
setGDTpar:
	xor eax, eax             ;
	push bx                  ; Save bx
	mov ax, ds               ; Segment addr
	shl eax, 4               ; Segment*16
	lea bx, GDT              ; Offset
	add ax, bx               ; Linear Address calc
	mov (GDTR+2), eax        ; Setting Address  
	pop bx                   ; Recover bx
	ret                      ;
	
	
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
NULL_descr	db 0,0,0,0,0,0,0,0											; 0 zero descriptor
CODE_descr	db 0FFh,0FFh,00h,00H,00H,10011010b, 11001111b,00h	; 1 code main code descriptor
DATA_descr	db 0FFh, 0FFh, 00h, 00h, 00h, 10010010b, 11001111b, 00h	; 2 data main descriptor
GDT_16bitCS	db 0FFh, 0FFh, 0, 0, 0, 10011010b, 0, 0			; 3 16-bit code descriptor
GDT_16bitDS	db 0FFh, 0FFh, 0, 0, 0, 10010010b, 0, 0			; 4 16-bit data descriptor

gdt_free_cells         db (GDT_COUNT-1-5) DUP (6 DUP(0))                ; Setting zeros for (5-8191 records)	

GDT_DESCR:

GDT_size = (GDT_DESCR - GDT)
GDTR	dw (GDT_size-1) 
		dd 0h

outOfProg:
	
	ret
	end _