	include printlib.lib 
	include pmode.lib 
	include ehci.lib
	include ehciCap.lib  
	include ehciOper.lib 
	include message.lib
	include pciconf.lib
	USBCode segment use16
	assume	cs:USBCode, ds:USBCode, es:USBCode
	.386p
	org 100h   

main proc far 

_:
	
	; Setting Default PCI Address 
	; ECX - parameter for searchUSBHCinPCI 
	mov ecx, (DEFAULT_ADDR + CLASS_SUBCLASS)
	call searchUSBHCinPCI
	
	call setProtectedMode     	; Setting FS register for Long Addressing 
	
	mov cx, 10            		; Counter for bar Amount
								; Address of Possible BAR 
	lea edx, HCBaseAddressStorage
	lea esi, HCPCIAddressStorage

;barLoop:

	mov ebx, dword ptr [edx]	; Gets Base address
	mov eax, dword ptr [esi]	; Gets PCI address 
	mov HCPCIAddress, eax 		; Write PCI address 
	cmp ebx, 0                  ; If Valid Base Address
	jz outOfBarLoop             ; Out in not Valid 
	mov HCBaseAddress, ebx 	    ; Save Base Address 
	call processEHCIHC			; Main Function 
	add edx, 4                  ; Mov to the next Base Address
	add esi, 4					; MOv to the next PCI 
	call printNewLineRM          
	
;	loop barLoop

outOfBarLoop:

	int 20h 	

; =====================================================================================================
; Extra libs

initPrint
initProtectedMode
initEHCI
initOperationalInfo
messageLib
initCapacityInfo
initPCIConfig

; =====================================================================================================

	main endp
	USBCode ends
	end _
