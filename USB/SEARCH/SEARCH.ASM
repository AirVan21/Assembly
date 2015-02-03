	include printlib.lib
	include uhci.lib
	model tiny
	.CODE
	.486
	org 100h   ;  Going to create .COM file

_:	
	jmp start  ;  Marker to place, where program starts
	
; INTEGER CONST
CONFIG_ADDR  = 0CF8h     ; Specifies configuration access  
CONFIG_DATA  = 0CFCh     ; Place where data will be transfered
DEFAULT_ADDR = 80000000h ; First PCI ADDR

; PCI Configuration space registers displacement
DEVICE_VENDOR = 0h       ; [Device(31-16),Vendor(15-0)] 
CLASS_SUBCLASS = 08h     ; [ClassCode(31-24), SubClass(23-16), Prog IF(15-8), Revision ID(7-0)]
USB_ID = 0C03h           ; 0x0C - Class, 0x03 - SubClass
BAR0 = 10h               ; #0
BAR1 = 14h               ; #1
BAR2 = 18h               ; #2
BAR3 = 1Ch               ; #3 
BAR4 = 20h               ; #4
BAR5 = 24h               ; #5   

start:

	mov ecx, (DEFAULT_ADDR + CLASS_SUBCLASS); Setting PCI Address 

; Main search function

search:
	mov eax, ecx          ; for OUT command
	mov dx, CONFIG_ADDR   ; sets out PORT address
	out dx, eax           ; sends request
	mov dx, CONFIG_DATA   ; sets input PORT address
	in  eax, dx           ; gets data from PCI device
	
	cmp ax, -1             ; check valid payload
	
	jz nextDevice          ; if (invalid) then handle next device      
	call getPCIInfo        ; Extract valuable info 
	jmp nextFunction       ; Goes to check next function		

getPCIInfo:
	push eax               ; Save eax
	push eax               ;
	pop  ax                ;
	pop  ax                ; gets first 16 bit of eax
	cmp  ax, USB_ID        ; is USB device?
	pop  eax               ; Recover EAX
	jz   getUSBInfo        ; Handle USB
	ret                    ;

; Handles USB device
getUSBInfo:
	push si                ; Save, help for storage
	push dx                ;
	push eax               ;
	push eax               ;
	mov ah, 09h            ;
	lea dx, descrip        ;
	int 21h                ; Print template for Class
	pop eax                ; 
	shr eax, 16            ; Set alone word (Class && Subclass)
	push ax                ; Parameter for print
	call printWordFromStackRM; (Class && Subclass) 
	pop eax                ;
	shr eax, 8             ; (Getting Prog IF)
	and ax, 00FFh          ; 
	push ax                ;
	mov si, ax             ; Saved Prog IF in SI
	call printByteFromStackRM; (Prog IF)
	mov ax, si             ; Parameter for Definition in ax
	call displayUSBtype    ; 
	mov ah, 09h            ; 
	lea dx, newLine        ; 
    int 21h                ;
	call displayBARs       ; Display PCI BARS
	pop dx                 ; Recover
	pop si                 ;
	ret                    ; Out from getPCIinfo call

; Prints information about USB class
displayUSBtype:            ; ax - parameter
	cmp ax, 0h             ;
	jz  showusb00          ; UHCI
	cmp ax, 10h            ;
	jz  showusb10          ; OHCI
	cmp ax, 20h            ;
	jz  showusb20          ; EHCI
	cmp ax, 30h            ;
	jz  showusb30          ; xHCI

   showusb00:
	lea dx, usb_00         ;
	jmp outUSBtype         ;

   showusb10:
	lea dx, usb_10         ;
	jmp outUSBtype         ;

   showusb20:
	lea dx, usb_20         ;
	jmp outUSBtype         ;

   showusb30:
	lea dx, usb_20         ;
	
outUSBtype:                ; Point to jump out of type definition
	mov ah, 09h            ; Print string
	int 21h                ;
	ret                    ;

displayBARs:
	push ecx               ; 
	push dx                ;
	push si                ;
	push di                ;
	push ebx               ;
	sub cx, CLASS_SUBCLASS ; cuz ECX firstly for CLASS retriving 
	add cx, BAR0           ; first BAR offset
	mov esi, ecx           ; Address

	mov ah, 09h            ; Print title
	lea dx, bars           ;
	int 21h                ;
	lea dx, newLine        ; CLRF
	int 21h                ;
	lea dx, space          ; Correct Output
	int 21h                ; 
	; Beauty part
	mov cx, 6              ; Amount of bars SET this variable!
   
   cycbar:
	mov eax, esi           ; USB Device PCI Address (ecx) 
	add si, 04h            ; Next Bar
	mov dx, CONFIG_ADDR    ; sets out PORT address
	out dx, eax            ; sends request
	mov dx, CONFIG_DATA    ; sets input PORT address
	in  eax, dx            ; gets data from PCI device
	cmp ax, 0h             ; valid if nonzero
	jz nextbar             ; jump to next bar 
	
	mov di,  ax            ; save lower 16 bits
	shr eax, 16            ; set alone high 16 bits
	push ax                ; 
	call printWordFromStackRM; Printing 1-st part
	push di                ; 
 	call printWordFromStackRM; Printing 2-nd part
	mov ah, 09h            ; Printing new line
	lea dx, newLine        ;
	int 21h                ;
	

	pop ebx                ; ebx containes BAR address
	
	; Template for saving BARs

	;lea eax, DevBARs       ; Address for BAR Storrage
	;mov dx, cx             ;
	;shl dx, 4              ; (4 bytes per BAR)
	;add ax, dx             ;
	;mov [eax], ebx         ; Writes BAR address             
	call printHCinfo       ; Prints Host Contriller registers parameters             
 
   nextbar:	

	loop cycbar            ; loop it
	
	pop ebx                ; 
	pop di                 ; Recover
	pop si                 ;
	pop dx                 ;
	pop ecx                ;
	ret                    ;
	
nextDevice:
	and ecx, 0FFFFF800h    ; Clear all before device part
	add ecx, 800h          ; Device step 
	add ecx, CLASS_SUBCLASS; Add Displacement (Purpose Search)
	test ecx, 800000h      ; First Number out of Bus Digit
	jz search              ; Next device iteration
	jmp outOfProgram       ; Out of program
		
nextFunction:
	add ecx, 100h          ; Function step
	test ecx, 800000h      ; First out of Bus digit
	jz search              ; Next function iteration


; =====================================================================================================
; Extra libs

initPrint

initUHCI

; =====================================================================================================
; STRING CONST 

hex_table db '0123456789ABCDEF'
usb_00    db ' UHCI (Universal Host Controller)$'
usb_10    db ' OHCI (Open Host Controller)$'
usb_20    db ' EHCI (Enhanced Host Controller)$'
usb_30    db ' xHCI (Extensible Host Controller)$'
descrip   db ' Class-SubClass-ProgIF = $'
newLine   db 13, 10, '$'
bars      db ' BARs (0-5):$'
space     db '   $'

; =====================================================================================================
; USB Devices BARs

DevBARs:

	dd ?
	dd ?
	dd ?
	dd ? 
	dd ?
	dd ?
	dd ?
	dd ?
	dd ?
	dd ?

outOfProgram:

	ret
	end _
		
	
