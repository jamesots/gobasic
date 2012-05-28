%{
package main

import (
	"os"
	"fmt"
	"strconv"
	"container/list"
)	

var varcounter int

var result Code

type Code struct {
	code *list.List
	numb int
	state int
	str string
}

const (
	CODE = iota
)

func PushAll(from Code, to Code) {
	for e := from.code.Front(); e != nil; e = e.Next() {
		to.code.PushBack(e.Value)
	}
}

func PrintAll(file *os.File, from Code) {
	for e := from.code.Front(); e != nil; e = e.Next() {
		var s = e.Value.(string)
		file.WriteString(s)
	}
}

func WriteCode(code *Code, format string, a ...interface{}) {
	res := fmt.Sprintf(format, a...)
	code.code.PushBack(res)
}

func NewCode(code *Code) {
	code.code = list.New()
	code.state = CODE
}

%}


%union
{
	numb	int
	cmd	string
	code	Code
	str	string
	vvar	string
}

%type	<code>	all
%type	<code>	line
%type	<code>	prog
%type	<code>	numexpr
%type	<code>	strexpr
%type	<code>	expr
%type	<code>	printcmd
%type	<code>	gotocmd
%type	<code>	letcmd
%type	<code>	letstrcmd
%type	<code>	line
%type	<code>	cmds
%type	<code>	cmd

%token	<numb>	NUM
%token	<code>	PRINT
%token	<code>	GOTO
%token	<code>	LET
%token	<vvar>	VAR
%token	<vvar>	STRVAR
%token	<str>	STRING

%left	'+' '-'
%left	'*'
%left	':'

%%

all:
	prog
	{
		result = $1
	}

prog:
	line
	{
		NewCode(&$$)
		PushAll($1, $$)
	}
|	line '\n' prog
	{
		NewCode(&$$)
		PushAll($1, $$)
		PushAll($3, $$)
	}

line:
	NUM cmds
	{
		NewCode(&$$)
		WriteCode(&$$, "line%d:\n", $1)
		PushAll($2, $$)
	}

cmds:
	cmd
	{
		NewCode(&$$)
		PushAll($1, $$)
	}
|	cmd ':' cmds
	{
		NewCode(&$$)
		PushAll($1, $$)
		PushAll($3, $$)
	}

cmd:
	printcmd
|	letcmd
|	letstrcmd
|	gotocmd
	{
		NewCode(&$$)
		PushAll($1, $$)
	}

letstrcmd:
	LET STRVAR '=' strexpr
	{
		if $4.state == STRING {
			NewCode(&$$)
			WriteCode(&$$, ".section .data\n")
			WriteCode(&$$, "str%s:\n", $2)
			WriteCode(&$$, "	.asciz \"%s\"\n", $4.str)
			WriteCode(&$$, ".section .code\n")
			// how to store a string?
		}
	}

letcmd:
	LET VAR '=' numexpr
	{
		NewCode(&$$)
		if $4.state == NUM {
			WriteCode(&$$, "	ldr r0, =%d\n", $4.numb)
		} else {
			PushAll($4, $$)
		}
		WriteCode(&$$, "	ldr r1, =var%s\n", $2)
		WriteCode(&$$, "	str r0, [r1]\n")
	}

gotocmd:
	GOTO NUM
	{
		NewCode(&$$)
		WriteCode(&$$, "	bl line%d\n", $2)
	}

printcmd:
	PRINT expr
	{
		NewCode(&$$)
		if $2.state == NUM {
			WriteCode(&$$, "	ldr r0, =%d\n", $2.numb)
		} else if $2.state == STRING {
			varcounter += 0
			WriteCode(&$$, ".section .data\n")
			WriteCode(&$$, "str%d:\n", varcounter)
			WriteCode(&$$, "	.asciz \"%s\"\n", $2.str)
			WriteCode(&$$, ".section .code\n")
			WriteCode(&$$, "	ldr r0, =str%d\n", varcounter)
		} else {
			PushAll($2, $$)
		}
		WriteCode(&$$, "	bl dabble\n")
		WriteCode(&$$, "	bl print\n")
	}

expr:
	numexpr
|	strexpr

strexpr:
	STRING
	{
		$$.state = STRING
		$$.str = $1
	}
|	STRVAR
	{
		NewCode(&$$)
		WriteCode(&$$, "	ldr r0, =str%s\n", $1)
	}
|	strexpr '+' strexpr
	{
		if $1.state == STRING && $3.state == STRING {
			$$.state = STRING
			$$.str = $1.str + $3.str
		} else {
			NewCode(&$$)
			if $1.state == STRING {
				// add STRING to something
				// need to handle memory allocations
			} else {
				PushAll($1, $$)  // add whatever we have to something
			}
			if $3.state == STRING {
				// add something to STRING
			} else {
				PushAll($3, $$)
				WriteCode(&$$, "	mov r1, r0\n")
			}
			// add them somehow
		}
	}

numexpr:
	NUM
	{
		$$.state = NUM
		$$.numb = $1
	}
|	VAR
	{
		NewCode(&$$)
		WriteCode(&$$, "	ldr r0, =var%s\n", $1)
	}
|	numexpr '+' numexpr
	{
		if $1.state == NUM && $3.state == NUM {
			$$.state = NUM
			$$.numb = $1.numb + $3.numb
		} else {
			NewCode(&$$)
			if $1.state == NUM {
				WriteCode(&$$, "	ldr r0, =%d\n", $1.numb)
			} else {
				PushAll($1, $$)
			}
			if $3.state == NUM {
				WriteCode(&$$, "	ldr r1, =%d\n", $3.numb)
			} else {
				PushAll($3, $$)
				WriteCode(&$$, "	mov r1, r0\n")
			}
			WriteCode(&$$, "	add r0, r0, r1\n")
		}
	}
|	numexpr '*' numexpr
	{
		if $1.state == NUM && $3.state == NUM {
			$$.state = NUM
			$$.numb = $1.numb + $3.numb
		} else {
			NewCode(&$$)
			if $1.state == NUM {
				WriteCode(&$$, "	ldr r0, =%d\n", $1.numb)
			} else {
				PushAll($1, $$)
			}
			if $3.state == NUM {
				WriteCode(&$$, "	ldr r1, =%d\n", $1.numb)
			} else {
				PushAll($3, $$)
				WriteCode(&$$, "	mov r1, r0\n")
			}
 			WriteCode(&$$, "	mul r0, r0, r1\n")
		}
	}
|	numexpr '-' numexpr
	{
		if $1.state == NUM && $3.state == NUM {
			$$.state = NUM
			$$.numb = $1.numb + $3.numb
		} else {
			NewCode(&$$)
			if $1.state == NUM {
				WriteCode(&$$, "	ldr r0, =%d\n", $1.numb)
			} else {
				PushAll($1, $$)
			}
			if $3.state == NUM {
				WriteCode(&$$, "	ldr r1, =%d\n", $1.numb)
			} else {
				PushAll($3, $$)
				WriteCode(&$$, "	mov r1, r0\n")
			}
 			WriteCode(&$$, "	sub r0, r0, r1\n")
		}
	}

%%

type BobLex int // the int here is the input that yyParse takes

var tok int
var strs []string

func (BobLex) Lex(yylval *yySymType) int {
	if tok < len(strs) {
		t := strs[tok]
		fmt.Println("TOKEN: ", t)
		tok = tok + 1;
		if t[0] >= '0' && t[0] <= '9' {
			num, _ := strconv.Atoi(t)
			yylval.numb = num
			return NUM
		}
		if t == "PRINT" {
			yylval.cmd = t
			return PRINT
		}
		if t == "GOTO" {
			yylval.cmd = t
			return GOTO
		}
		if t == "LET" {
			yylval.cmd = t
			return LET
		}
		if t[0] >= 'A' && t[0] <= 'Z' {
			if t[len(t)-1] == '$' {
				yylval.vvar = t[0:len(t)-1]
				return STRVAR
			} else {
				yylval.vvar = t
				return VAR
			}
		}
		if t[0] == '"' {
			yylval.str = t[1:len(t)-1]
			return STRING
		}
		return int(t[0])
	}
	return 0
}

func (BobLex) Error(s string) {
	fmt.Println("Error ", s)
}

func Parse(strs []string) {
	fmt.Println("Start")
	tok = 0
	varcounter = 0

	res := yyParse(BobLex(0))
	fmt.Println("End ", res)
}

/**
TODO:
FOR VAR '=' expr TO expr [STEP expr] -- when are exprs calculated?
NEXT VAR

STRINGS
INPUT
DATA
ARRAYS
FILES
WHILE..WEND
IF..THEN..ELSE

string storage

need a heap
strvar points to an address
address points to a null terminated string on the heap
*/
