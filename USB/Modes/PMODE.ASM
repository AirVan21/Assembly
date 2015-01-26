	model tiny
	.386p
	.CODE
	org 100h          		 ;  Going to create .COM file

_:

	jmp start  ;  Marker to place, where program starts	

; INT CONSTS
CMOS_PORT_ID   = 70h         ; Port for CMOS memory access	

VIDEO_BASE     = 0B8000h     ; Video memory for color monitors
CODE_LIMIT     = 1024        ; 

; GDT parameters
GDT_size = (GDT_end - GDT)
GDT_param	dw (GDT_size-1)  ; GDT Limit
		    dd 0h            ; GDT Address

; Descriptor Offsets
CODE_SELECTOR    = 08h        ; Code
STACK_SELECTOR   = 10h        ; Stack 
DATA_SELECTOR    = 18h        ; Data 
SCREEN_SELECTOR  = 20h        ; Data

; ACCESS RIGHTS 
CODE_ACCESS_R    = 10010110b  ; P ; DPL ; S ; Type ; A ;
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
	
	; Sets Code Descriptor
	mov bx, offset GDT + 8          ; Skip Null-Descriprot, point to CODE_DESCRIPTOR 
	                                ; DS is set
	push cs                         ; For Code Segment Address
	pop ax                          ; 
	shl eax, 10h                    ; Code Segment Address
	mov edx, 2048                   ; Simple segment limit
	mov cl, CODE_ACCESS_R           ; Code access rights
	call setDescriptor              ; 
	
	; Sets Stack Descriptor
	lea dx, STACK_SEG_START         ; Stack Segment Start Address
	add eax, offset STACK_SEG_START ; Code Segment Address + Mark offset
	mov dx, (STACK_SEG_START - DATA_SEG_END) ; Stack limit
	mov cl, STACK_ACCESS_R          ; Stack access rights
	call setDescriptor              ;

	; Sets Data Descriptor
	xor eax, eax                    ;
	xor edx, edx                    ;
	push cs                         ; For Code Segment Address
	pop ax                          ; 
	shl eax, 10h                    ; Code Segment Address
	lea dx, DATA_SEG_START          ; Data Segment Start Address
	add eax, edx                    ; 
	mov dx, (DATA_SEG_END - DATA_SEG_START); Data Limit
	mov cl, DATA_ACCESS_R           ; Data access right 
	call setDescriptor              ;

	; Sets Screen Descriptor
	mov eax, VIDEO_BASE             ; Video Segment Address
	mov	edx, 4000	                ; Video Segment Size (80 * 25 * 2 = 4000).
	mov cl, STACK_ACCESS_R          ; Screen access rights
	call setDescriptor              ;

	call setParamGDT           		; Calculate GDT address, size
	mov edi, dword ptr [GDT_param] 	; Load argument
	
	call disable_interrupts         ; Disables interrupts
	lgdt [edi]               		; Load GDT   
	
	; Moving to Protected Mode 
	mov	eax, cr0                    ; Getting signalling register
	or	al, 1                       ; Sets bit for Protected mode
	mov	cr0, eax                     ; Save changes

	call enable_interrupts          ; Enables interrupts

	; We are in protected mode      ;
	db 0EAh	                        ; far jmp CODE_SELECTOR : pmCode 
	dw pmCode                       ; Argument for jump command
	dw CODE_SELECTOR                ; Argument for jump command
	
	jmp outOfProg                   ; End program

setParamGDT:
	push eax                        ; Save eax
	push bx                  		; Save bx
	xor eax, eax             		;
	mov ax, ds               		; Segment Address
	shl eax, 4               		; Segment * 10h (alignment)
	lea bx, GDT              		; Offset
	add ax, bx               		; Linear Address calc
	mov dword ptr [(GDT_param+2)], eax; Setting Address  
	pop bx                   		; Recover bx
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
    
    add bx, 08h                    ; Add 8 bytes to access next descriptor 
	
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

pmCode:
	; Sets appropriate selectors

	mov	ax, SCREEN_SELECTOR
	mov	es, ax           ; Points to prepared screen descriptor 

	mov	ax,DATA_SELECTOR
	mov	ds,ax			 ; Points to prepared data descriptor 

	mov	ax, STACK_SELECTOR
	mov	ss, ax           ; Points to prepared stack descriptor  
	mov	sp, 0
	
	jmp printMsg

; Printing example
printMsg:

	mov bl, 05h         ; Print Style
	mov di, 480         ; 3rd raw

	mov al, 'H'
	mov [edi], al
	mov [edi+1], bl
	
	mov al, 'e'
	mov [edi+2], al
	mov [edi+3], bl
	
	mov al, 'l'
	mov [edi+4], al
	mov [edi+5], bl
	
	mov al, 'l'
	mov [edi+6], al
	mov [edi+7], bl
	
	mov al, 'o'
	mov [edi+8], al
	mov [edi+9], bl
	
	mov al, '!'
	mov [edi+10], al
	mov [edi+11], bl

	dw 0CD20h            ; Out of program

; =====================================================================================================

; The main Global Descriptors Table (GDT) (shuold have 8192 records) 
GDT_COUNT = 8192

GDT:

NULL_descr	db 0,0,0,0,0,0,0,0	; NULL_DESCRIPTOR (never referenced)
; CODE_DESCRIPTOR
; STACK_DESCRIPTOR
; DATA_DESCRIPTOR
; SCREEN_DESCRIPTOR
; |    Part 1     |                              |      ACCESS RIGHTS     |Part 2|        | 
; [Address(31-24) ; G ; D ; X ; U ; Limit(19-16) ; P ; DPL ; S ; Type ; A ; Address(23-0) ; Limit(15-0)]
; 63           56  55  54  53  52   51        48  47  46 45 44   43 41 40   39         16   15        0

GDT_free_cells   db (10) DUP (6 DUP(0)) ; Setting zeros for (all records)	

GDT_end:

; ======================================================================================================
; Data Part

DATA_SEG_START:

Message db 'Hello!'

DATA_SEG_END:

; ======================================================================================================
; Stack Part

db	1024 DUP (0)	; Memory which reserved for stack

STACK_SEG_START:	; Mark for stack

outOfProg:
	
	ret
	
	end _
