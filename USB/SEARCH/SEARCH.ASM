	include printlib.lib
	include uhci.lib
	searchHC segment use16
	assume	cs:searchHC, ds:searchHC, es:searchHC
	.386
	org 100h   ;  Going to create .COM file

main proc far 

_:	
	
	jmp start  ;  Marker to place, where program starts
	
; =====================================================================================================
; Extra CONSTs

; INTEGER CONST
CONFIG_ADDR   = 0CF8h     ; Specifies configuration access  
CONFIG_DATA   = 0CFCh     ; Place where data will be transfered
DEFAULT_ADDR  = 80000000h ; First PCI ADDR
DEVICE_STEP   = 800h      ; Device Step on PCI detour 
FUNCTION_STEP = 100h      ; Function Step on PCI detour   

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

; =====================================================================================================

start:

	mov ecx, (DEFAULT_ADDR + CLASS_SUBCLASS); Setting PCI Address 

; Main search function

search:

	mov eax, ecx			; for OUT command
	mov dx, CONFIG_ADDR		; sets out PORT address
	out dx, eax 			; sends request
	mov dx, CONFIG_DATA		; sets input PORT address
	in  eax, dx				; gets data from PCI device
	
	cmp ax, -1              ; check valid payload
	
	jz nextDevice           ; if (invalid) then handle next device      
	call getPCIInfo         ; Extract valuable info 
	jmp nextFunction        ; Goes to check next function		

getPCIInfo:

	push eax               ; PCI Class-SubClass information here 
	shr eax, 16            ; Class-SubClass in ax 
	cmp  ax, USB_ID        ; is USB device?
	pop  eax               ; Recover EAX
	
	jz getUSBInfo          ; Handle USB
	
	db 0C3h                ; ret 

; Handles USB device
getUSBInfo:

	push si                ; Save, help for storage
	push dx                ;
	push eax               ;
	push eax               ;
	mov ah, 09h            ;
	lea dx, descrip        ;
	int 21h                ; Print Template for Class
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
	call processBARs       ; Process PCI BARS
	
	pop dx                 ; Recover
	pop si                 ;
	
	db 0C3h                ; ret 

; Prints information about USB class
;
; AX - containes USB HC class parameter
displayUSBtype:
    
    push dx					; Save dx 
 
    ; AX - parameter
	cmp ax, 0h             ;
	jz  showusb00          ; UHCI
	cmp ax, 10h            ;
	jz  showusb10          ; OHCI
	cmp ax, 20h            ;
	jz  showusb20          ; EHCI
	cmp ax, 30h            ;
	jz  showusb30          ; xHCI

   showusb00:
	lea dx, usb_00         ; Sets Appropriate String 
	jmp outUSBtype         ; 

   showusb10:
	lea dx, usb_10         ; Sets Appropriate String 
	jmp outUSBtype         ;

   showusb20:
	lea dx, usb_20         ; Sets Appropriate String 
	jmp outUSBtype         ;

   showusb30:
	lea dx, usb_30         ; Sets Appropriate String 
	
outUSBtype:                ; Point to jump out of type definition
	mov ah, 09h            ; Print string
	int 21h                ;
	
	pop dx                 ; Recover DX

	db 0C3h                ; ret 

processBARs:
	
	push ecx               ; Save registers
	push dx                ;
	push si                ;
	push di                ;
	
	sub cx, CLASS_SUBCLASS ; Cuz ECX firstly for CLASS retriving 
	add cx, BAR0           ; First BAR offset
	mov esi, ecx           ; Address for PCI device

	; Prints Headers
	mov ah, 09h            ; Print title
	lea dx, bars           ;
	int 21h                ;
	
	mov cx, 6              ; Amount of bars | (set this variable)
   
   cycbar:
	mov eax, esi           ; USB Device PCI Address (ecx) 
	add si, 04h            ; Next Bar
	mov dx, CONFIG_ADDR    ; Sets out PORT address
	out dx, eax            ; Sends request
	mov dx, CONFIG_DATA    ; Sets input PORT address
	in  eax, dx            ; Sets data from PCI device
	cmp ax, 0h             ; Valid if nonzero
	jz nextbar             ; Jump to next bar 
	
	call saveBARValue		; Saves Base Address

	mov di,  ax            ; save lower 16 bits
	shr eax, 16            ; set alone high 16 bits
	push ax                ; 
	call printWordFromStackRM; Printing 1-st part
	push di                ; 
 	call printWordFromStackRM; Printing 2-nd part
	mov ah, 09h            ; Printing new line
	lea dx, newLine        ;
	int 21h                ;
	           
   nextbar:	

	loop cycbar            ; loop it
	
	pop di                 ; Recover
	pop si                 ;
	pop dx                 ;
	pop ecx                ;

	db 0C3h                ; ret 

; Saves Base Address For Future Processing
; 
; EAX - Contains Base Address
saveBARValue:
	
	push eax 				; Save registers
	push ebx                ; 
	push ecx                ;

	push eax                ; Store Base Address (which should be stored)
	
	; Saves Base Address to Storage
	lea ebx, HCBaseAddressStorage

	mov cx, 10              ; Amount of Possible BAR (to save)

  storageCycle:
	
	mov eax, dword ptr [ebx]; Get BAR from storage 
	cmp eax, 0              ; If Empty then Write In Mem 
	jz writeBarToStorrage   ;
	add ebx, 8              ; Mov to the next place 

	loop storageCycle       ;
  
  writeBarToStorrage:
	
	pop eax                 ; Get Base Address
	mov [ebx], eax          ; Save BA in Memory 
	
	pop ecx                 ;   
	pop ebx                 ; Recover registers
	pop eax                 ; 

	db 0C3h                ; ret               

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

; =====================================================================================================
; STRING CONST 

hex_table db '0123456789ABCDEF'
usb_00    db ' UHCI (Universal Host Controller)$'
usb_10    db ' OHCI (Open Host Controller)$'
usb_20    db ' EHCI (Enhanced Host Controller)$'
usb_30    db ' xHCI (Extensible Host Controller)$'
descrip   db ' Class-SubClass-ProgIF = $'
newLine   db 13, 10, '$'
bars      db ' Valid BAR : $'
space     db '  $'

; =====================================================================================================
; USB Devices BARs

HCBaseAddressStorage:

	dd 0h 	; #1 
	dd 0h 	; #2
	dd 0h 	; #3
	dd 0h 	; #4
	dd 0h 	; #5
	dd 0h 	; #6
	dd 0h 	; #7
	dd 0h 	; #8
	dd 0h 	; #9
	dd 0h 	; #10 

outOfProgram:

	int 20h 

	main endp
	searchHC ends
	end _

		
	
