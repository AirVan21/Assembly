	model tiny
	.CODE
	.386p
	org 100h          		 ;  Going to create .COM file

_:

	jmp start  ;  Marker to place, where program starts	

; INT CONSTS
CMOS_PORT_ID   = 70h         ; Port for CMOS memory access	

STACK_BASE     = 1024*1024*5 ; 
VIDEO_BASE     = 0B8000h     ; Video memory for color monitors

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
ACCESS_RIGHTS   = 

start:

; Sets Protected Mode
set_prot_mode:

	call setParamGDT           		; Calculate GDT address, size

	mov edi, dword ptr [GDT_param] 	; Load argument
	
	lgdt [edi]               		;  
	
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

setDescriptor:
	push eax                       ; Save eax
	push ecx                       ; Save ecx

	mov cx, ax                     ; Copy first (Jr) part of Address
	shl ecx, 10h                   ; Shift 
	mov cx, dx                     ; Copy first (Jr) part of Limit

	mov [bx], ecx                  ; Writing descriptors first (Jr) part 

	shr eax, 10h                   ; Shift 16-bit (Second part of Address now)
	mov cl, ah                     ; To cl bit (24-31) from Address  (Part 1)
	shl ecx, 18h                   ; Kill ecx byte
	mov cl, al                     ; To cl bit (16-23) from Address  (Part 2)

	mov ax, ACCESS_RIGHTS          ;
	mov ch, al                     ; Acess to 2-nd ecx byte
                                   ; Oldest Limit part is zero
                                   ; G D X U      part is zero


	pop ecx                        ; Recover ecx
	pop eax                        ; Recover eax                       
	ret

; The main Global Descriptors Table (GDT) (shuold have 8192 records) 
GDT_COUNT = 8192

GDT:

NULL_descr	db 0,0,0,0,0,0,0,0					
			    ; null descriptor (never referenced)

; CODE_DESCRIPTOR
; STACK_DESCRIPTOR
; DATA_DESCRIPTOR
; SCREEN_DESCRIPTOR
; |    Part 1     |                              |      ACCESS RIGHTS     |    Part 2     |
; [Address(31-24) ; G ; D ; X ; U ; Limit(19-16) ; P ; DPL ; S ; Type ; A ; Address(23-0) ; Limit(15-0)]
; 63           56  55  54  53  52   51        48  47  46 45 44   43 41 40   39         16   15        0

GDT_free_cells   db (GDT_COUNT - 2) DUP (6 DUP(0))                  ; Setting zeros for (all records)	

GDT_end:



outOfProg:
	
	ret
	
	end _
