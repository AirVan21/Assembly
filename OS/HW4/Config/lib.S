# Clears screen
clrscr:

    pushl %edx
    pushl %ecx
    pushl %eax

    # Video-Mem
    movl $0xB8000, %edx
    # Amount of symbols to clean
    movl $0x650,   %ecx
    xor %eax, %eax
    movb $' ',%al
    movb $0,  %ah
  
  putspace:
    movw %ax, (%edx)
    add $2, %edx
    loop putspace

    popl %eax
    popl %ecx
    popl %edx

    ret

# Disavles all IRQs from PIC
disable_pic_ints:

    pushl %eax

    # Disable all IRQs
    in  $0x21, %ax 
    mov $0xFF, %ax
    out %ax, $0x21

    popl %eax

    ret

# Print line until get '\0'
#
# @params ebx - containts line address
print_line_until_null:

    pushl %ebx
    pushl %edx
    pushl %eax

    movl video_memory, %edx
    xorl %eax, %eax
    # Color
    movb $COLOR, %ah

  print_char_until_null:
    
    movb (%ebx), %al
    
    cmp $0, %al
    jz out_print_line_until_null

    # Print char 
    movw %ax, (%edx)
    # Mov to the next char
    inc %ebx
    # Mov to the next position on a screen 
    addl $2, %edx 

    jmp print_char_until_null

  out_print_line_until_null:

    # Saves filled video_memory position
    movl %edx, video_memory

    popl %eax
    popl %edx
    popl %ebx

    ret

# Recalculates video_memory for the new string
videomem_newline:

    pushl %eax
    pushl %ebx
    pushl %edx

    movl video_memory, %eax
    subl $VMEM_START, %eax
    movl $160, %ebx
    xorl %edx, %edx

    # Remainder in edx
    divl %ebx
    # Chars to line end
    movl $160, %ebx
    subl %edx, %ebx
    movl video_memory, %eax
    addl %ebx, %eax
    # Points on new line in VMEM
    movl %eax, video_memory

    popl %edx
    popl %ebx
    popl %eax

    ret

# prints number from %ebx register
#
# @param number in %ebx - register
print_number_from_register:
    
    pushl %eax
    pushl %ebx
    pushl %ecx

    # Saves original
    movl %ebx, %eax
    
    shrl $28, %ebx
    call print_char_from_number_table

    movl %eax, %ebx
    shrl $24, %ebx
    andl $0x0F, %ebx
    call print_char_from_number_table

    movl %eax, %ebx
    shrl $20, %ebx
    andl $0x0F, %ebx
    call print_char_from_number_table

    movl %eax, %ebx
    shrl $16, %ebx
    andl $0x0F, %ebx
    call print_char_from_number_table

    movl %eax, %ebx
    shrl $12, %ebx
    andl $0x0F, %ebx
    call print_char_from_number_table

    movl %eax, %ebx
    shrl $8, %ebx
    andl $0x0F, %ebx
    call print_char_from_number_table

    movl %eax, %ebx
    shrl $4, %ebx
    andl $0x0F, %ebx
    call print_char_from_number_table

    movl %eax, %ebx
    andl $0x0F, %ebx
    call print_char_from_number_table

    popl %ecx
    popl %ebx
    popl %eax

    ret

# print char with hex-number in %ebx
#
# @ebx contains offset of char in %ebx table
print_char_from_number_table:

    pushl %eax
    pushl %ebx
    pushl %ecx

    xorl %ecx, %ecx
    
    # Address of number-table
    leal hex_table, %eax
    # %eax points on a valid char
    addl %ebx, %eax

    movb (%eax), %cl
    movb $COLOR, %ch

    movl video_memory, %ebx
    movw %cx, (%ebx)
    addl $2, %ebx
    movl %ebx, video_memory

    popl %ecx
    popl %ebx
    popl %eax

    ret
    