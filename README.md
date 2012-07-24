gobasic
=======

A BASIC Compiler for ARM (specifically, Raspberry Pi), written in Go.

This project was just an exercise in playing with Go, ARM assembly and my 
Rasberry Pi. It is not a well designed programme. I have never written a compiler
before, and it is many years since I used yacc.

The compiler compiles to ARM assembly, and then you have to compile the generated
assembly to get a programme. You can use the example in the makefile. I may include
it in the compiler tool eventually, now I think of it.

Part of the challenge of this is to write things myself, wherever possible. I lifted
the idea of the doubledabble routine from Wikipedia. The memory management is non-
existent so far, but once it is written, it's almost guaranteed to be terrible!

It supports a very small subset of BASIC so far. When in doubt, I'll probably mostly
refer back to Mallard BASIC and BBC BASIC for how things should work. And then
I'll just hack in whatever I want, until it isn't recognisable as BASIC. Like most
other BASICs, then.

Features
* FOR..TO..NEXT loops (but no STEP)
* PRINT variables, constant strings or numerical expressions
* integers only
* IF..THEN..ELSE on logical numerical expressions
* numerical expressions can use + - * / % ( )
* logical expressions can use < <= > >= = <> AND OR NOT
* multiple expressions per line, separated by :
* LET must be used to assign variables
* GOTO is evil, but it's part of BASIC, so in it goes
* can assign variables, integer expressions, or constant strings
