	model tiny
	.CODE
	.486
	org 100h   ;  Going to create .COM file

_:	
	jmp start  ;  Marker to place, where program starts

; STRING CONST 
hex_table db '0123456789ABCDEF'
; INTEGER CONST
CONFIG_ADDR  = 0CF8h     ; Specifies configuration access  
CONFIG_DATA  = 0CFCh     ; Place where data will be transfered
DEFAULT_ADDR = 80000000h ; First PCI ADDR
; PCI Configuration space registers displacement
DEVICE_VENDOR = 0h       ; [Device(31-16),Vendor(15-0)] 
CLASS_SUBCLASS = 08h     ; [ClassCode(31-24), SubClass(23-16), Prof IF(15-8), Revision ID(7-0)]
BAR0 = 10h               ; #0
BAR1 = 14h               ; #1
BAR2 = 18h               ; #2
BAR3 = 1Ch               ; #3 
BAR4 = 20h               ; #4
BAR3 = 24h               ; #5   

start:

	mov ecx, (DEFAULT_ADDR + CLASS_SUBCLASS); Setting PCI Address 

search:
	mov eax, ecx          ; for OUT command
	mov dx, CONFIG_ADDR   ; sets out PORT address
	out dx, eax           ; sends request
	mov dx, CONFIG_DATA   ; sets input PORT address
	in  eax, dx           ; gets data from PCI device
	
	cmp ax, -1             ; check valid payload
	
	jz nextDevice          ; if (invalid) then handle next device     
	call getPCIInfo        ; Extract valueble info 
	jmp nextFunction       ; Goes to check next function		

printWordFromStack:

	xor eax, eax           ; Clear
	pop  ax                ; Pop value, which should be printed
	push dx                ; Save DX
	push di                ; Save DI
	push si                ; Save SI
	push cx                ; Save CX
	mov di, ax             ; Storage for value to print
	mov cx, 4              ; Cycle counter
	lea bx, hex_table      ; Load in bx char table
	mov si, 12             ; Shift counter
cycle:
	mov ax, di             ; Set default value
	shr ax, si             ; Shift
	and ax, 0Fh            ; Set digit alone
	xlat                   ; Translate
	mov dl, al             ; Result to DL 
	mov ah, 02h            ; Print char code
	int 21h                ; 
	sub si, 4              ;
	loop cycle             ;
	
	pop cx                 ; Restore registers
	pop si                 ;
	push di                ;
	push dx                ;
	ret                    ; 
	
nextDevice:
	and ecx, 0FFFFF800h    ; Clear all before device part
	add ecx, 800h          ; Device step 
	add ecx, CLASS_SUBCLASS; Add Displacement (Purpose Search)
	test ecx, 800000h      ; First Number out of Bus Digit
	jz search              ; Next device iteration
	jmp lastPrint          ; Out of program
		
nextFunction:
	add ecx, 100h          ; Function step
	test ecx,800000h       ; First out of Bus digit
	jz search              ; Next function iteration  
	
	end _
		
	
