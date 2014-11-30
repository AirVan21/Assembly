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

outOfProg:


/*
	Last Edition
*/

+ 

; Temp Storage
ss_prev dw 0h                ; Right stack  buffer

savecr0 dd 0                 ; CR0	

idt_real:
	dw 0x3ff				; 256 entries, 4b each = 1K
	dd 0					; Real Mode IVT @ 0x0000


	; moving to Real Mode
	;mov eax, cr0
	;mov dword ptr [savecr0], eax
	;and eax, 7FFFFFFEh	            ; Disable paging bit & enable 16-bit pmode.
	;mov cr0, eax           		
	;jmp 0:switchToRm		       ; Perform Far jump to set CS.
 
;switchToRm:
;	mov ax, 80h                    ;
;	mov sp, ax		               ; pick a stack pointer.
;	mov ax, word ptr [ss_prev]	   ; Reset segment registers to 0.
;	mov ds, ax
;	mov es, ax
;	mov fs, ax
;	mov ss, ax
;	lidt dword ptr [idt_real]

	
	ret
	end _