	include printlib.lib 
	include pmode.lib 
	include ehci.lib
	include ehciCap.lib  
	include ehciOper.lib 
	include message.lib
	include pciconf.lib
	include control.lib
	USBCode segment use16
	assume	cs:USBCode, ds:USBCode, es:USBCode
	.386p
	org 100h   

main proc far 

start:
	
	; Setting Default PCI Address 
	; ECX - parameter for searchUSBHCinPCI 
	mov ecx, (DEFAULT_ADDR + CLASS_SUBCLASS)
	call searchUSBHCinPCI
	
	; Setting FS register for Memory Addressing
	call setProtectedMode     	

	; Handle found Host Controllers 
	xor edi, edi 
	mov cx, NumberOfValidHC
  
  loopOverHC:  
	
	lea edx, HCBaseAddressStorage
	lea esi, HCPCIAddressStorage
	mov ebx, dword ptr [edx + edi]	; Gets Base address
	mov eax, dword ptr [esi + edi]	; Gets PCI address 
	mov HCPCIAddress, eax 			; Write PCI address 
	cmp ebx, 0                  	; If Valid Base Address
	jz outLoopOverHC            	; Out in not Valid 
	
	mov HCBaseAddress, ebx 	    	; Save Base Address 
	call processEHCIHC				; Main Function 
	add edi, 4                      ; Offset for HC Addresses 

    loop loopOverHC  

  outLoopOverHC:

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
initControlLib

; =====================================================================================================

	main endp
	USBCode ends
	end start 
