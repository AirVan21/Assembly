	include printlib.lib
	include ehciOper.lib
	include ehciCap.lib
	include ehci.lib
	.386p
	pmode segment use16
	assume	cs:pmode, ds:pmode, es:pmode

	org 100h          		 ;  Going to create .COM file

main proc far

_:

	jmp start  				  ;  Marker to place, where program starts	

; INT CONSTS
ROWLENGTh      = 80 * 2       ; 80 Symbols x (1 Byte for Char + 1 Byte for Style)
CMOS_PORT_ID   = 70h          ; Port for CMOS memory access	

VIDEO_BASE     = 0B8000h      ; Video memory for color monitors
CODE_LIMIT     = 1024         ;
STACK_LIMIT    = 1024         ; 
GDT_SIZE       = (GDT_end - GDT) - 1

; Operational registers
USBCMDoffset   = 00h
USBSTSoffset   = 04h
PeriodLBoffset = 14h
PORTSCOffset   = 44h 

; Descriptor Offsets
CODE_SELECTOR    = 8          ; Code
STACK_SELECTOR   = 16         ; Stack 
DATA_SELECTOR    = 24         ; Data 
SCREEN_SELECTOR  = 32         ; Data
MEMORY_SELECTOR  = 40         ; Data
RM_CODE_SELECTOR = 48         ; Real Mode Code
RM_DATA_SELECTOR = 56         ; Real Mode Data

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
RM_CODE_ACCESS_R = 10011010b  ; 
RM_DATA_ACCESS_R = 10010010b  ; 	

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
	shl eax, 4                      ; Code Segment Address
	;add bx, 8                       ; 
	mov dx, CODE_LIMIT              ; Simple segment limit
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

	; Memory (Zero) Descriptor
				                     ; Zero Address Descriptor is hardcoded 
	add bx, 8                        ; Moves to the next descriptor
	

	call setParamGDT           		; Calculate GDT address, size
	
	; Sets extra RM Code Descriptor
	xor eax, eax                    ;
	push cs                         ; Code Segment
	pop ax                          ; AX = CS 
	shl eax, 4                      ;
	mov edx, 0FFFFh                 ; Limit 64K 
	mov cl, RM_CODE_ACCESS_R        ; 

	call setDescriptor              ;
	
	; Sets extra RM Data Descriptor 
	mov cl, RM_DATA_ACCESS_R        ;

	call setDescriptor              ; 

	call disable_interrupts         ; Disables interrupts
	
	lgdt GDTR               		; Load GDT   	

	; Moving to Protected Mode 
	mov	eax, cr0                    ; Getting signalling register
	or	al, 1                       ; Sets bit for Protected mode
	mov	cr0, eax                    ; Save changes
        
	; We are in protected mode      ;
	db 0eah	                        ; far jmp CODE_SELECTOR : pmCode 
	dw setMainRegister              ; Argument for jump command
	dw CODE_SELECTOR                ; Argument for jump command
	

setMainRegister:

	; Sets appropriate selectors

	mov	ax, SCREEN_SELECTOR
	mov	es, ax           			; Points to prepared screen descriptor 

	mov	ax, DATA_SELECTOR
	mov	ds, ax			 			; Points to prepared data descriptor 

	mov	ax, STACK_SELECTOR
	mov	ss, ax           			; Points to prepared stack descriptor  
	mov	sp, 0
	
	mov ax, MEMORY_SELECTOR         ; Points to prepared zero-mem descriptor
	mov fs, ax                      ;

	jmp printInVMem      

; Prints string to Video Memory
printInVMem:
	
	
	mov edi, 160                    ; 2nd Row
	call  printEHCIInfo             ; Prints info about EHCI Capacity Registers 


loop_dead:                          ; Dead loop
	
	jmp	loop_dead



; Fill correct parameters for GDT register
setParamGDT:
	
	push eax                        ; Save eax
	push edx                        ; Save edx
	
	xor eax, eax             		;
	
	mov ax, ds               		; Segment Address
	shl eax, 4              	    ; Segment (alignment)
	lea dx, GDT              		; Offset
	add eax, edx               		; Linear Address calc
	mov GDT_adr, eax                ; Setting Address  
	mov dx, GDT_SIZE                ;
	mov GDT_lim, dx                 ;
	
	pop edx                  		; Recover bx
	pop eax                         ; Recover eax
	
	db 0C3h                         ; ret

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

	shr edx, 16                    ; Oldest Limit Part 
	and dx, 0Fh                    ; Set only last 4-bits
	pop ax                         ; Get Acess right 
	mov ch, al                     ; Acess to 2-nd ecx byte
                                   ; Oldest Limit part is zero
                                   ; G D X U      part is zero
    mov [bx + 4], ecx              ; Writing descriptors second part
    mov [bx + 6], dl               ; Write Oldest Part
    add bx, 8                      ; Add 8 bytes to access next descriptor 
	
	pop ecx                        ; Recover ecx
	pop eax                        ; Recover eax                       
	
	db 0C3h                        ; ret

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
	
	db 0C3h              ; ret

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
	
	db 0C3h              ; ret


; =====================================================================================================
; Extra libs

initEHCI
initPrint
initCapacityInfo
initOperationalInfo


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
; MEMORY_DESCRIPTOR
; |    Part 1     |                              |      ACCESS RIGHTS     |Part 2|        | 
; [Address(31-24) ; G ; D ; X ; U ; Limit(19-16) ; P ; DPL ; S ; Type ; A ; Address(23-0) ; Limit(15-0)]
; 63           56  55  54  53  52   51        48  47  46 45 44   43 41 40   39         16   15        0

; Setting zeros for (all records)

	; Descriptors for Protected Mode
	dd 	?, ?  
	dd  ?, ?
	dd 	?, ?
	dd 	?, ?
	dd 	?, ?
	db  0FFh, 0FFh, 00h, 00h, 00h, 10010010b, 11001111b, 00h	; Descriptor for Zero Memory Point 
	
	; Descriptors for Real Mode
	dd 	?, ?
	dd 	?, ?

GDT_end:

; ======================================================================================================
; PM Data Part

DATA_SEG_START:
; STRING CONSTS 
GreetMsg  db "Protected mode on!$"
hex_table db "0123456789ABCDEF"
CapLenMsg db "CAPLENGTH Register = $"
HCVersion db "EHCI Revision      = $"
N_PORTS   db "Number of HC Ports = $"
HCGreet   db "Host Controller    = $"
USBCMDmsg db "USBCMD Register    = $"
USBSTSmsg db "USBSTS Register    = $"
PListBase db "Periodic List Base = $"
PORTSCMsg db "PORTSC Register    = $"

; INT CONSTS
CAPLENGTH dw  020h
  

DATA_SEG_END:

; ======================================================================================================
; PM Stack Part


	db 1024 DUP (0)	; Memory which reserved for stack


STACK_SEG_START:	; Mark for stack

; ======================================================================================================


	main endp
	pmode ends
	end _
