	model tiny
	.CODE
	.386
	org 100h   ;  Going to create .COM file

_:

; CONSTS
CMOS_PORT   = 70h     ; port for CMOS memory access	
STATUS_PORT = 64h     ; port for SHUTDOWN
SHUT_DOWN   = 0FEh    ; CP SHUTDOWN commmand
real_sp   dw
real_ss   dw
real_es   dw

	jmp start  ;  Marker to place, where program starts	
	
start:

set_prot_mode:
	
	call disable_interrapts ; Disable Maskable && Non-Maskable interrupts
	mov  [real_ss],ss       ; запоминаем указатель стека
    mov  [real_es],es       ; для реального режима
	lgdt [GDTR]             ; Load GDT
	; Exit()
	jmp outOfProg         ;
	
	
set_real_mode:
	mov [real_sp], sp       ; Saving SP

	; CPU Shut Down
    mov al,SHUT_DOWN
    out STATUS_PORT,al
	; Ожидаем сброса процессора

wait_reset:
    hlt
    jmp     wait_reset
		
	; -->> В это место мы попадём после сброса процессора,
	; теперь мы снова в реальном режим
		
	; Восстанавливаем указатель стека
    mov     ss,[real_ss]
    mov     sp,[real_sp]
	; Восстанавливаем содержимое регистра es
    mov     es,[real_es]
	; Разрешаем прерывания
	call enable_interrupts;
	; Exit()
	jmp outOfProg         ;
	
disable_interrupts:
	xor eax, eax      ;
	cli               ; Blocking Maskable Interrupts
	in  al, CMOS_PORT ; Getting CMOS-byte
	or  al, 80h       ; First bit for Non-Maskable
	                  ; 0 - Enabled, 1 - Disables
	out al, CMOS_PORT ; Disabling NMI 
	ret               ;

enable_interrupts:
	xor eax, eax      ;
	in  al, CMOS_PORT ; Getting CMOS-byte
	and al, 7Fh       ; Setting first bit to zero 
	                  ; 0 - Enables NMI
	out al, CMOS_PORT ;
	ret               ;

; The main global descriptors table, 8192 records 
GDT_COUNT = 8192

GDT:
NULL_descr		db 0,0,0,0,0,0,0,0											; 0 zero descriptor
CODE_descr		db 0FFh,0FFh,00h,00H,00H,10011010b, 11001111b,00h			; 1 code main code descriptor
DATA_descr		db 0FFh, 0FFh, 00h, 00h, 00h, 10010010b, 11001111b	, 00h	; 2 data main descriptor
GDT_16bitCS     db 0FFh, 0FFh, 0, 0, 0, 10011010b, 0, 0						; 3 16-bit code descriptor
GDT_16bitDS     db 0FFh, 0FFh, 0, 0, 0, 10010010b, 0, 0						; 4 16-bit data descriptor
gdt_free_cells:	
times(GDT_COUNT-1-5)	db 0,0,0,0,0,0,0,0									; 5-8191 records	

GDT_size = _ - GDT
GDTR			dw GDT_size-1
				dd GDT
				
outOfProg:
	
	ret
	end _