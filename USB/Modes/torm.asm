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
	
	ret
	end _