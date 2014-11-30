	model tiny
	.CODE
	.486p
	org 100h          		 ;  Going to create .COM file

_:

	jmp start  ;  Marker to place, where program starts	

; INT CONSTS
CMOS_PORT_ID   = 70h         ; Port for CMOS memory access	
CODE_DESC_OFFS = 08h         ; Code Descriptor Offset
DATA_DESC_OFFS = 10h         ; Data Descriptor Offset
STACK_BASE     = 1024*1024*5 ; 
VIDEO_BASE     = 0B8000h     ; Video memory for color monitors
; Temp Storage
ss_prev dw 0h                ; Right stack  buffer

savecr0 dd 0                 ; CR0	

idt_real:
	dw 0x3ff				; 256 entries, 4b each = 1K
	dd 0					; Real Mode IVT @ 0x0000

start:

set_prot_mode:

	call disable_interrupts   		; Disable Maskable && Non-Maskable interrupts
	call setGDTpar           		; Calculate GDT size
	mov edi, dword ptr [GDTR]		; Load argument
	lgdt [edi]               		;  
	call CODE_DESC_OFFS:switchToPm  ; Setting in CS register Code Selector  
	call enable_interrupts          ; Enable Maskable && Non-Maskable interrupts
	jmp outOfProg                   ; End program
	
	; moving to Real Mode
	mov eax, cr0
	mov dword ptr [savecr0], eax
	and eax, 7FFFFFFEh	            ; Disable paging bit & enable 16-bit pmode.
	mov cr0, eax           		


	jmp 0:switchToRm		       ; Perform Far jump to set CS.
 
switchToRm:
	mov ax, 80h                    ;
	mov sp, ax		               ; pick a stack pointer.
	mov ax, word ptr [ss_prev]	   ; Reset segment registers to 0.
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov ss, ax
	lidt dword ptr [idt_real]
	

switchToPm:
	mov word ptr [ss_prev], ds      ;
	mov ax, DATA_DESC_OFFS          ; Setting Data Selector
	mov ds, ax                      ; 
	mov es, ax                      ; Selector of Data Segment
	mov ss, ax                      ; Figure out problems with stack! 
	mov esp, STACK_BASE             ;  	
	;call remap_irq                 ; Remaps IRQ
	call printPMGreating            ; Prints test output in Video Memory

	ret

setGDTpar:
	xor eax, eax             		;
	push bx                  		; Save bx
	mov ax, ds               		; Segment addr
	shl eax, 4               		; Segment*16
	lea bx, GDT              		; Offset
	add ax, bx               		; Linear Address calc
	mov dword ptr [(GDTR+2)], eax           ; Setting Address  
	pop bx                   		; Recover bx
	ret                      		;

; Simple Video Mem Case
printPMGreating:
	push edi                 ; Saves edi
	push bx                  ; Saves bx
	push ax                  ;
	mov edi, VIDEO_BASE      ; Pointer to Video Mem 
	mov bl, 05h              ; DOS-Print Style
	
	mov al, 'P'
	mov [edi], al          
	mov [edi+1], bl           

	mov al, 'M'
	mov [edi+2], al                     
	mov [edi+3], bl          
           
	mov al, ' '
	mov [edi+4], al          
	mov [edi+5], bl
           
	mov al, 'm'
	mov [edi+6], al          
	mov [edi+7], bl  
	           
	mov al, 'o'
	mov [edi+8], al          
	mov [edi+9], bl 
         
	mov al, 'd'
	mov [edi+10], al          
	mov [edi+11], bl 
           
	mov al, 'e'
	mov [edi+12], al          
	mov [edi+13], bl 

	pop edi                  ; Recover
	pop bx                   ;
	pop ax                   ;
	ret

; Printing string. Address in stack
stringPrinter:
	
	push bx                  ;
	push edi                 ;
	push ax                  ;
	push cx                  ; Counter
	xor dx, dx               ; Clear 
	xor cx, cx               ;
	mov dl, 07h              ; Color
	mov edi, VIDEO_BASE      ; Setting VIDEO_BASE
	add edi, (80*20)         ; Displacement for print
	
   printChar:
	xor ebx, ebx
	lea ebx, pm_str
        add bx, cx                ;
	mov al, [5F8Eh:bx]        ; Char From string
	cmp al, '$'               ;
	jz outPrint               ;
	shl cx, 1                 ;
	mov bx, cx                ;
	add ebx, edi              ;
	mov [ebx], al             ;    
	mov [ebx + 1], dl         ;
	add cx, 1
	jmp printChar             ;
  
   outPrint:
	pop bx
	pop edi
	pop ax
	pop cx	
	ret      


; Remaps the external interrupts
remap_irq:
	mov al, 11h
	out 20h,al		; Initialize master PIC
	
	mov al, 11h
	out 0A0h,al		; Initialize slave PIC
	
	mov al, 20h
	out 21h, al		; Int 0 should be at 20h int
	
	mov al, 28h
	out 0A1h,al		; int 8 should be at 28h
	
	mov al, 04h
	out 21h,al		; Tell the master PIC that IRQ line 2 is mapped to the slave PIC
	
	mov al, 02h
	out 0A1h,al		; Tell the slave PIC that IRQ line 2 is mapped to the master PIC
	
	mov al, 01h
	out 21h, al		; Setting bit 0 enables 80x86 mode
   
	mov al, 01h
	out 0A1h,al		;Setting bit 0 enables 80x86 mode
   
	xor al,al
	out 21h, al
	out 0A1h,al
	
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


; The main Global Descriptors Table (GDT), 8192 records 
GDT_COUNT = 8192

GDT:
NULL_descr	db 0,0,0,0,0,0,0,0									; null descriptor (never referenced)
CODE_descr	db 0FFh,0FFh,00h,00H,00H,10011010b, 11001111b,00h	; 1 code main code descriptor (kernel)
DATA_descr	db 0FFh, 0FFh, 00h, 00h, 00h, 10010010b, 11001111b, 00h	; 2 data main descriptor
GDT_16bitCS	db 0FFh, 0FFh, 0, 0, 0, 10011010b, 0, 0			    ; 3 16-bit code descriptor
GDT_16bitDS	db 0FFh, 0FFh, 0, 0, 0, 10010010b, 0, 0		        ; 4 16-bit data descriptor

gdt_free_cells         db (GDT_COUNT-1-5) DUP (6 DUP(0))        ; Setting zeros for (5-8191 records)	

GDT_DESCR:

GDT_size = (GDT_DESCR - GDT)
GDTR	dw (GDT_size-1) 
		dd 0h

TERMINATE db 0CDh, 20h

outOfProg:
	jmp outOfProg            		;
	
	ret
	end _