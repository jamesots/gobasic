prog: prog.o
	ld -o prog prog.o

prog.S: prog.bas gobasic
	./gobasic prog.bas

prog.o: prog.S
	gcc -nostartfiles -Wa,-ahls=prog.list,-L -ggdb -o prog.o prog.S

clean:
	rm prog prog.o prog.S

gobasic: gobasic.go
	go build


