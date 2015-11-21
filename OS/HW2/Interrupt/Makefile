CC ?= gcc
LD ?= ld

all: hello

hello: hello.o linker.ld
	$(LD) -m elf_i386 -nostdlib -T linker.ld -o hello hello.o

hello.o: hello.S
	$(CC) -m32 -c hello.S -o hello.o

.PHONEY: all clean

clean:
	rm -r *.o 
	rm hello

