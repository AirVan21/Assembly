	include printlib.lib 
	include pmode.lib 
	include ehci.lib 
	include ehciCap.lib 
	include ehciOper.lib 
	searchHC segment use16
	assume	cs:searchHC, ds:searchHC, es:searchHC
	.386p
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
OUT_OF_BUS    = 800000h   ; First out of Bus digit   

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

	; Setting Default PCI Address 
	mov ecx, (DEFAULT_ADDR + CLASS_SUBCLASS)

; Main Search Function
; Retrievs information about PCI Device from Configuration space
;
; ECX - Contains PCI Address
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

; Review PCI Configuration Space Info
; Continue Processing only USB HCs
;
; ECX - Contains PCI Address
getPCIInfo:

	push eax               ; PCI Class-SubClass information here 
	shr eax, 16            ; Class-SubClass in ax 
	cmp  ax, USB_ID        ; It is USB HC device?
	pop  eax               ; Recover EAX
	
	jz processUSBHC        ; Handle USB HCs  
	
	db 0C3h                ; ret 

; Retrievs in PCI(USB) Device Nonzero BAR 
; Continue Processing only USB HCs
;
; ECX - Contains PCI Address
processUSBHC:
	
	push ecx               ; Save registers
	push dx                ;
	push si                ;
	
	sub cx, CLASS_SUBCLASS ; Cuz ECX firstly for CLASS retriving 
	add cx, BAR0           ; First BAR offset
	mov esi, ecx           ; Address for PCI device
	
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
           
   nextbar:	

	loop cycbar            ; loop it
	
	pop si                 ;
	pop dx                 ;
	pop ecx                ;

	db 0C3h                ; ret 

; Saves Base Address For Future Processing
; 
; EAX - Contains Base Address
; ECX - Contains PCI Address
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
	add ebx, 4              ; Mov to the next place 

	loop storageCycle       ;
  
  writeBarToStorrage:
	
	pop eax                 ; Get Base Address
	mov [ebx], eax          ; Save BA in Memory 
	
	pop ecx                 ;   
	pop ebx                 ; Recover registers
	pop eax                 ; 

	db 0C3h                ; ret               

; Continue PCI device detour with DEVICE_STEP increase in address 
; 
nextDevice:
	and ecx, 0FFFFF800h    		; Clear all before device part
	add ecx, DEVICE_STEP   		; Device step 
	add ecx, CLASS_SUBCLASS		; Add Displacement (Purpose Search)
	test ecx, OUT_OF_BUS   		; First Number out of Bus Digit
	jz search              		; Next device iteration
	jmp outOfBARCheck      		; Out of BAR Check 

; Continue PCI device detour with FUNCTION_STEP increase in address 
; 		
nextFunction:
	add ecx, FUNCTION_STEP 		; Function step
	test ecx, OUT_OF_BUS   		; First out of Bus digit
	jz search              		; Next function iteration

outOfBARCheck:
	
	call set_prot_mode     		; Setting FS register for Long Addressing 
	
	mov cx, 10            		; Counter for bar Amount
								; Address of Possible BAR 
	lea edx, HCBaseAddressStorage

barLoop:

	mov ebx, dword ptr [edx]	; Gets address
	cmp ebx, 0                  ; If Valid Base Address
	jz outOfBarLoop             ; Out in not Valid
	call printEHCIInfo          ; Print Info For Valid
	add edx, 4                  ; Mov to the next 
	call printNewLineRM          
	
	loop barLoop

outOfBarLoop:

	int 20h 	

; =====================================================================================================
; Extra libs

initPrint
initProtectedMode
initEHCI
initCapacityInfo
initOperationalInfo

; =====================================================================================================
; USB Devices BARs

HCBaseAddressStorage:

	dw 0h 	; #1 
	dw 0h 	; #2
	dw 0h 	; #3
	dw 0h 	; #4
	dw 0h 	; #5
	dw 0h 	; #6
	dw 0h 	; #7
	dw 0h 	; #8
	dw 0h 	; #9
	dw 0h 	; #10 

	main endp
	searchHC ends
	end _

		
	
