	model tiny
	.CODE
	.386
	org 100h          ;  Going to create .COM file

_:

; CONSTS
CMOS_PORT_ID   = 70h  ; Port for CMOS memory access	
STATUS_PORT = 64h     ; Port for SHUTDOWN
SHUT_DOWN   = 0FEh    ; CP SHUTDOWN commmand
;real_sp   dw
;real_ss   dw
;real_es   dw

	jmp start  ;  Marker to place, where program starts	
	
start:

set_prot_mode:
	
	call disable_interrupts  ; Disable Maskable && Non-Maskable interrupts
	;mov  [real_ss],ss       ; Save Stack Pointer
    ;mov  [real_es],es       ; 
	;lgdt [GDTR]             ; Load GDT
	; Exit()
	jmp outOfProg            ;
	
	
disable_interrupts:
	xor eax, eax         ;
	push dx, dx          ; Save dx
	cli                  ; Blocking Maskable Interrupts
	mov dl, CMOS_PORT_ID ; (Params should be registers)
	in  al, dl           ; Getting CMOS-byte
	or  al, 80h          ; First bit for Non-Maskable
	                     ; 0 - Enabled, 1 - Disables
	out al, dl           ; Disabling NMI 
	pop dx               ; Recover dx
	ret                  ;

enable_interrupts:
	xor eax, eax         ;
	push dx, dx          ; Save dx
	mov dl, CMOS_PORT_ID ; 
	in  al, dl           ; Getting CMOS-byte
	and al, 7Fh          ; Setting first bit to zero 
	                     ; 0 - Enables NMI
	out al, dl           ;
	pop dx               ; Recover dx
	ret                  ;

GDT_DESCR:

; The main Global Descriptors Table (GDT), 8192 records 
GDT_COUNT = 8192

GDT:
NULL_descr		db 0,0,0,0,0,0,0,0											; 0 zero descriptor
CODE_descr		db 0FFh,0FFh,00h,00H,00H,10011010b, 11001111b,00h			; 1 code main code descriptor
DATA_descr		db 0FFh, 0FFh, 00h, 00h, 00h, 10010010b, 11001111b	, 00h	; 2 data main descriptor
GDT_16bitCS		db 0FFh, 0FFh, 0, 0, 0, 10011010b, 0, 0						; 3 16-bit code descriptor
GDT_16bitDS		db 0FFh, 0FFh, 0, 0, 0, 10010010b, 0, 0						; 4 16-bit data descriptor

;gdt_free_cells         db (GDT_COUNT-1-5) DUP (6 DUP(0))                  ; Setting zeros for
;times(GDT_COUNT-1-5)	db 0,0,0,0,0,0,0,0									; 5-8191 records	

GDT_size = GDT_DESCR - GDT
GDTR	   dw GDT_size-1
	   dd GDT

outOfProg:
	
	ret
	end _