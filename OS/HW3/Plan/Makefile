CC ?= gcc
LD ?= ld

all: plan

plan: plan.o linker.ld
	$(LD) -m elf_i386 -T linker.ld -o plan plan.o

plan.o: plan.S
	$(CC) -g -m32 -c plan.S -o plan.o

.PHONEY: all clean

clean:
	rm -r *.o 
	rm plan

