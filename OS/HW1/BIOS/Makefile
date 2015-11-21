CC ?= gcc
LD ?= ld

LFLAGS := -Ttext 0x7c00 --oformat=binary
# -Ttext 0x7c00    : Code should be loaded at 0x7c00
# --oformat=binary : Output file should be plain binary

all: hello

hello: hello.o 
	$(LD) ${LFLAGS} hello.o -o hello

hello.o: hello.S
	$(CC) -c hello.S -o hello.o

.PHONY: clean all

clean:
	rm -f *.o hello
