	.386p
	pm segment use16
	assume	cs:pm, ds:pm, es:pm

	org 100h          		 ;  Going to create .COM file

main proc far

_:

;============================================================
; Define CONSTS 

; INT CONSTS
CMOS_PORT_ID   = 70h         		; Port for CMOS memory access	

VIDEO_BASE     = 0B8000h     		; Video memory for color monitors
CODE_LIMIT     = 1024        		;
STACK_LIMIT    = 1024        		;
GDT_SIZE       = (GDT_end - GDT) - 1; 

; Descriptor Offsets
CODE_SELECTOR    = 8          		; Code
STACK_SELECTOR   = 16         		; Stack 
DATA_SELECTOR    = 24         		; Data 
SCREEN_SELECTOR  = 32         		; Data

; ACCESS RIGHTS 
CODE_ACCESS_R    = 10011000b  		; P ; DPL ; S ; Type ; A ;
							  		; P    = 1b   Segment presence in memory
							  		; DPL  = 00b  Descriptor Privelege Level (00b for 0 system level)
							  		; S    = 1b   System object (1b for Code segment or Data segment)
					          		; Type = 011b Segment Type
					          		; A    = 0b   Access
STACK_ACCESS_R   = 10010110b  		;
DATA_ACCESS_R    = 10010010b  		;
SCREEN_ACCESS_R  = 10010010b  		; 	
	
	xor eax, eax                    ;
	xor edx, edx                    ;

	; Sets Code Descriptor
	mov	bx, offset GDT + 8	
	
	push cs                         ; For Code Segment Address
	pop ax                          ; 
	shl eax, 4                      ; Code Segment Address
	mov dx, CODE_LIMIT              ; Simple segment limit
	mov cl, CODE_ACCESS_R           ; Code access rights
	
	call setDescriptor              ; 

	; Sets Stack Descriptor
	lea	dx, STACK_SEG_START         ; Stack Segment Start Address
	add	eax,edx	                    ; Code Segment Address + Mark offset
	mov	dx, STACK_LIMIT             ; Stack limit
	mov	cl, STACK_ACCESS_R          ; Stack access rights

	call setDescriptor	            ; 

	; Sets Data Descriptor
	xor eax, eax                    ;
	mov ax, ds                      ;
	shl eax, 4                      ; Code Segment Address
	xor ecx, ecx                    ;
	lea cx, DATA_SEG_START          ; Data Segment Start Address
	add eax, ecx                    ; 
	lea dx, DATA_SEG_END            ; Data Limit Calculation
	sub dx, cx                      ; Correct Data Limit in cx
	mov cl, DATA_ACCESS_R           ; Data access right 
	
	call setDescriptor              ;

	; Sets Screen Descriptor
	mov eax, VIDEO_BASE             ; Video Segment Address
	mov	edx, 4000	                ; Video Segment Size (80 * 25 * 2 = 4000).
	mov cl, SCREEN_ACCESS_R         ; Screen access rights
	
	call setDescriptor              ;

	; Setting GDTR:
	xor	eax,eax						; EAX = 0
	mov	edx,eax						; EDX = 0

	mov	ax,ds
	shl	eax,4						; EAX = физический адрес начала сегмента данных.
	lea	dx,GDT
	add	eax,edx						; EAX = физический адрес GDT
	mov	GDT_adr,eax	; Записываем его в поле адреса образа GDTR.

	mov	dx,39		; Предел GDT = 8 * (1 + 4) - 1
	mov	GDT_lim,dx	; Записываем его в поле предела образа GDTR.

	cli		

	lgdt	GDTR		; Загружаем образ GDTR в сам регистр GDTR.

	; Moving to Protected Mode 
	mov	eax, cr0		; Getting signalling register
	or	al, 1           ; Sets bit for Protected mode
	mov	cr0, eax 		; Save changes

	; We are in protected mode      ;
	db	0eah			; far jmp CODE_SELECTOR : printInVMem
	dw	printInVMem		; Argument for jump command
	dw	CODE_SELECTOR	; Argument for jump command

;--------------------------------------------------------------------------
printInVMem:
	; Sets appropriate selectors

	mov	ax, SCREEN_SELECTOR
	mov	es,ax

	mov	ax, DATA_SELECTOR
	mov	ds,ax

	mov	ax, STACK_SELECTOR
	mov	ss,ax
	mov	sp,0

	mov	bx, 0		; 

	mov	di, 480		; Выводим ZS-строку со смещения 480 в
				;  видеопамяти (оно соответствует началу
				;  3-й строки на экране в текстовом режиме).
	
	mov	ah,1bh		; В AH будет атрибут вывода - светло-циановые
				;  символы на синем фоне.

putzs_1:
	mov	al,[ bx ]	; Читаем байт из ZS-строки.
	inc	bx		; Переводим указатель на следующий байт.
	cmp	al,0		; Если байт равен 0,
	je	putzs_end	; то переходим в конец процедуры.

	mov	es:[di],ax	; Иначе - записываем символ вместе с
				;  атрибутом в видеопамять по заданному
				;  смещению - цветной символ появится на
				;  экране.

	add	di,2		; Переводим указатель в видеопамяти на
				;  позицию следующего символа. 

	jmp	putzs_1	; Повторяем процедуру для следующего байта
				;  из ZS-строки.

putzs_end:	

; Cycle

loop_1:
	
	jmp	loop_1

; Sets Descriptor
; Parameters:
; DS:BX - Descriptor in GDT
; EAX   - Segment address
; EDX   - Segment limit
; CL    - Access rights

setDescriptor:
	push eax                       ; Save eax
	push ecx                       ; Save ecx
	push cx                        ; Save Acess rights
	
	mov cx, ax                     ; Copy first (Jr) part of Address
	shl ecx, 16                    ; Shift 
	mov cx, dx                     ; Copy first (Jr) part of Limit

	mov [bx], ecx                  ; Writing descriptors first (Jr) part 

	shr eax, 16                    ; Shift 16-bit (Second part of Address now)
	mov cl, ah                     ; To cl bit (24-31) from Address  (Part 1)
	shl ecx, 24                    ; Kill ecx byte
	mov cl, al                     ; To cl bit (16-23) from Address  (Part 2)

	pop ax                         ; Get Acess right 
	mov ch, al                     ; Acess to 2-nd ecx byte
                                   ; Oldest Limit part is zero
                                   ; G D X U      part is zero
    mov [bx + 4], ecx              ; Writing descriptors second part
    
    add bx, 8                      ; Add 8 bytes to access next descriptor 
	
	pop ecx                        ; Recover ecx
	pop eax                        ; Recover eax                       
	
	db 0C3h                        ;

; =====================================================================================================

; GDT parameters
GDTR	label	fword

GDT_lim		dw	?
GDT_adr		dd	?

; The main Global Descriptors Table (GDT) (shuold have 8192 records) 

GDT:

; NULL_DESCRIPTOR (never referenced)
; CODE_DESCRIPTOR
; STACK_DESCRIPTOR
; DATA_DESCRIPTOR
; SCREEN_DESCRIPTOR
; |    Part 1     |                              |      ACCESS RIGHTS     |Part 2|        | 
; [Address(31-24) ; G ; D ; X ; U ; Limit(19-16) ; P ; DPL ; S ; Type ; A ; Address(23-0) ; Limit(15-0)]
; 63           56  55  54  53  52   51        48  47  46 45 44   43 41 40   39         16   15        0

; Setting zeros for (all records)

	dd 	?, ?  
	dd 	?, ?	
	dd 	?, ?
	dd 	?, ?
	dd 	?, ?

GDT_end:

; ======================================================================================================
; Data Part

DATA_SEG_START:	

db	"Hello, world! Protected mode on!",0	

DATA_SEG_END:		

; ======================================================================================================
; Stack Part

db	1024 dup (?)	

STACK_SEG_START:	

; ======================================================================================================
	
	main endp
	pm ends
	end	_