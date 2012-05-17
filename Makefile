prog: prog.S dabble.o
	gcc -nostartfiles -Wa,-ahls=prog.list,-L -ggdb -o prog prog.S dabble.o

prog.S: prog.bas gobasic
	./gobasic prog.bas

clean:
	rm prog prog.o prog.S

gobasic: gobasic.go
	go build


dabble.o: dabble.S
	gcc -Wa,-ahls=dabble.list,-L -c -ggdb -o dabble.o dabble.S
