	.386p
	pmode segment use16
	assume	cs:pmode, ds:pmode, es:pmode

	org 100h          		 ;  Going to create .COM file

_:

	jmp start  ;  Marker to place, where program starts	

; INT CONSTS
CMOS_PORT_ID   = 70h         ; Port for CMOS memory access	

VIDEO_BASE     = 0B8000h     ; Video memory for color monitors
CODE_LIMIT     = 1024        ;
STACK_LIMIT    = 1024        ; 
GDT_SIZE       = (GDT - GDT_end) - 1;

; GDT parameters
GDTR	label	fword

GDT_lim		dw	?
GDT_adr		dd	?

; Descriptor Offsets
CODE_SELECTOR    = 8          ; Code
STACK_SELECTOR   = 16         ; Stack 
DATA_SELECTOR    = 24h        ; Data 
SCREEN_SELECTOR  = 32h        ; Data

; ACCESS RIGHTS 
CODE_ACCESS_R    = 10011000b  ; P ; DPL ; S ; Type ; A ;
							  ; P    = 1b   Segment presence in memory
							  ;	DPL  = 00b  Descriptor Privelege Level (00b for 0 system level)
							  ; S    = 1b   System object (1b for Code segment or Data segment)
					          ; Type = 011b Segment Type
					          ; A    = 0b   Access
STACK_ACCESS_R   = 10010110b  ;
DATA_ACCESS_R    = 10010010b  ;
SCREEN_ACCESS_R  = 10010010b  ; 	

start:

; Sets Protected Mode
; Parameters:
; DS:BX - Descriptor in GDT
; EAX   - Segment address
; EDX   - Segment limit
; CL    - Access rights
set_prot_mode:
	
	xor eax, eax                    ;
	xor edx, edx                    ;

	; Sets Code Descriptor
	mov bx, offset GDT + 8          ; Skip Null-Descriprot, point to CODE_DESCRIPTOR 
	                                ; DS is set
	push cs                         ; For Code Segment Address
	pop ax                          ; 
	shl eax, 4h                     ; Code Segment Address
	mov edx, 2048                   ; Simple segment limit
	mov cl, CODE_ACCESS_R           ; Code access rights
	call setDescriptor              ; 
	
	; Sets Stack Descriptor
	lea dx, STACK_SEG_START         ; Stack Segment Start Address
	add eax, edx                    ; Code Segment Address + Mark offset
	mov dx, STACK_LIMIT             ; Stack limit
	mov cl, STACK_ACCESS_R          ; Stack access rights
	call setDescriptor              ;

	; Sets Data Descriptor
	xor eax, eax                    ;
	xor edx, edx                    ;
	push ds                         ; For Code Segment Address
	pop ax                          ; 
	shl eax, 04h                    ; Code Segment Address
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

	call setParamGDT           		; Calculate GDT address, size
	
	;call disable_interrupts         ; Disables interrupts
	cli                             ;
	
	lgdt GDTR               		; Load GDT   
	
	; Moving to Protected Mode 
	mov	eax, cr0                    ; Getting signalling register
	or	al, 1                       ; Sets bit for Protected mode
	mov	cr0, eax                     ; Save changes

	;call enable_interrupts          ; Enables interrupts


	; We are in protected mode      ;
	db 0eah	                        ; far jmp CODE_SELECTOR : pmCode 
	dw printInVMem                  ; Argument for jump command
	dw CODE_SELECTOR                ; Argument for jump command
	

setParamGDT:
	push eax                        ; Save eax
	push edx                        ; Save edx
	xor eax, eax             		;
	
	mov ax, ds               		; Segment Address
	shl eax, 4               		; Segment * 10h (alignment)
	lea dx, GDT              		; Offset
	add eax, edx               		; Linear Address calc
	mov GDT_adr, eax                ; Setting Address  
	mov GDT_lim, 79                 ;
	pop edx                  		; Recover bx
	pop eax                         ; Recover eax
	ret  

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
	shl ecx, 10h                   ; Shift 
	mov cx, dx                     ; Copy first (Jr) part of Limit

	mov [bx], ecx                  ; Writing descriptors first (Jr) part 

	shr eax, 10h                   ; Shift 16-bit (Second part of Address now)
	mov cl, ah                     ; To cl bit (24-31) from Address  (Part 1)
	shl ecx, 18h                   ; Kill ecx byte
	mov cl, al                     ; To cl bit (16-23) from Address  (Part 2)

	pop ax                         ; Get Acess right 
	mov ch, al                     ; Acess to 2-nd ecx byte
                                   ; Oldest Limit part is zero
                                   ; G D X U      part is zero
    mov [bx + 4], ecx              ; Writing descriptors second part
    
    add bx, 8                      ; Add 8 bytes to access next descriptor 
	
	pop ecx                        ; Recover ecx
	pop eax                        ; Recover eax                       
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

printInVMem:
	; Sets appropriate selectors

	mov	ax, SCREEN_SELECTOR
	mov	es, ax           ; Points to prepared screen descriptor 

	mov	ax, DATA_SELECTOR
	mov	ds,ax			 ; Points to prepared data descriptor 

	mov	ax, STACK_SELECTOR
	mov	ss, ax           ; Points to prepared stack descriptor  
	mov	sp, 0
	
	; Выводим ZS-строку:

	mov	bx, 0	; DS:BX = указатель на начало ZS-строки. Адрес
			;  сегмента данных определён по метке
			;  PMode_data_start, а строка начинается сразу после
			;  этой метки, её смещение от метки равно 0,
			;  следовательно, это и будет смещение от начала
			;  сегмента данных.

	mov	di, 480		; Выводим ZS-строку со смещения 480 в
				;  видеопамяти (оно соответствует началу
				;  3-й строки на экране в текстовом режиме).
	
	mov	ah, 1bh		; В AH будет атрибут вывода - светло-циановые
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

	;pop	di
	;pop	es
	;pop	bx
	;pop	ax
	
; Зацикливаем программу:

loop_1:
	
	jmp	loop_1

; =====================================================================================================

; The main Global Descriptors Table (GDT) (shuold have 8192 records) 
GDT_COUNT = 8192

GDT:

; NULL_DESCRIPTOR (never referenced)
; CODE_DESCRIPTOR
; STACK_DESCRIPTOR
; DATA_DESCRIPTOR
; SCREEN_DESCRIPTOR
; |    Part 1     |                              |      ACCESS RIGHTS     |Part 2|        | 
; [Address(31-24) ; G ; D ; X ; U ; Limit(19-16) ; P ; DPL ; S ; Type ; A ; Address(23-0) ; Limit(15-0)]
; 63           56  55  54  53  52   51        48  47  46 45 44   43 41 40   39         16   15        0

	dd 0h, 0h  ; Setting zeros for (all records)
	dd 0h, 0h	
	dd 0h, 0h
	dd 0h, 0h
	dd 0h, 0h

GDT_end:

; ======================================================================================================
; Data Part

DATA_SEG_START:

db "Hello, world!", 0

DATA_SEG_END:

; ======================================================================================================
; Stack Part

db	1024 DUP (0)	; Memory which reserved for stack

STACK_SEG_START:	; Mark for stack

outOfProg:
	
	ret
	
	pmode ends
	
	end _
