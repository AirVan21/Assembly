CC ?= gcc
LD ?= ld

all: acpi

acpi: acpi.o linker.ld
	$(LD) -m elf_i386 -T linker.ld -o acpi acpi.o

acpi.o: acpi.S lib.S
	$(CC) -g -m32 -c acpi.S -o acpi.o

.PHONEY: all clean

clean:
	rm -r *.o 
	rm acpi

