#GCC = arm-linux-gnueabi-gcc
GCC = gcc

prog: prog.S dabble.o print.o math.o mem.o
	$(GCC) -nostartfiles -Wa,-ahls=prog.list,-L -ggdb -o prog prog.S dabble.o print.o math.o mem.o

prog.S: prog.bas gobasic
	./gobasic prog.bas

clean:
	rm -if prog prog.S *.o gobasic *.list *.output compiler.S compiler.go

gobasic: gobasic.go compiler.go tok.go functions.go
	go build

compiler.go: compiler.y
	go tool yacc -o compiler.go -v compiler.output compiler.y

compiler: compiler.go
	go build compiler.go

%.o: %.S
	$(GCC) -Wa,-ahls=$*.list,-L -c -ggdb -o $*.o $*.S
