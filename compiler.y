%{
package main

import (
	"os"
	"fmt"
	"strconv"
	"container/list"
)	

var varcounter int
var forcounter int
var ifcounter int

var result Code

type LoopInfo struct {
	varname string
	limit   int
	forcount	int
}

var numvars *list.List
var strvars *list.List
var forvars *list.List

type Code struct {
	code *list.List
	numb int
	boo bool
	state int
	str string
}

const (
	CODE = iota
)

func Contains(l *list.List, item interface{}) bool {
	fmt.Println("Contains, looking for ", item)
	for e := l.Front(); e != nil; e = e.Next() {
		fmt.Println("Compare with: ", e.Value)
		if e.Value == item {
			fmt.Println("Found")
			return true
		}
	}
	fmt.Println("Not found")
	return false
}

func PushAll(to Code, from Code) {
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

func WriteCode(code Code, format string, a ...interface{}) {
	res := fmt.Sprintf(format, a...)
	code.code.PushBack(res)
}

func LoadNum(to Code, code Code) {
	if code.state == NUM {
		WriteCode(to, "	ldr r0, =%d\n", code.numb)
	} else {
		PushAll(to, code)
		WriteCode(to, "	pop {r0}\n")
	}
}

func LoadPushNum(to Code, code Code) {
	if code.state == NUM {
		WriteCode(to, "	ldr r0, =%d\n", code.numb)
		WriteCode(to, "	push {r0}\n")
	} else {
		PushAll(to, code)
	}
}

func CreateNumVar(to Code, varname string, val int) {
	if !Contains(numvars, varname) {
		WriteCode(to, ".section .data\n")
		WriteCode(to, "var%s:\n", varname)
		WriteCode(to, "	.word %d\n", val)
		WriteCode(to, ".section .text\n")
		numvars.PushBack(varname)
	}
}

func PushNum(to Code, reg int) {
	WriteCode(to, "	push {r%d}\n", reg)
}

func PopNum(to Code, reg int) {
	WriteCode(to, "	pop {r%d}\n", reg)
}

func LoadBool(to Code, code Code) {
	if code.state == BOOL {
		if code.boo {
			WriteCode(to, "	ldr r0, =1\n")
		} else {
			WriteCode(to, "	ldr r0, =0\n")
		}
	} else {
		PushAll(to, code)
		WriteCode(to, "	pop {r0}\n")
	}
}

func LoadPushBool(to Code, code Code) {
	if code.state == BOOL {
		if code.boo {
			WriteCode(to, "	ldr r0, =1\n")
		} else {
			WriteCode(to, "	ldr r0, =0\n")
		}
		WriteCode(to, "	push {r0}\n")
	} else {
		PushAll(to, code)
	}
}

func NewCode(code *Code) {
	code.code = list.New()
	code.state = CODE
}

%}


%union
{
	numb	int
	code	Code
	str	string
	vvar	string
}

%type	<code>	all
%type	<code>	line
%type	<code>	prog
%type	<code>	numexpr
%type	<code>	boolexpr
%type	<code>	strexpr
%type	<code>	expr
%type	<code>	printcmd
%type	<code>	gotocmd
%type	<code>	nextcmd
%type	<code>	letnumcmd
%type	<code>	letstrcmd
%type	<code>	fortocmd
%type	<code>	ifcmd
%type	<code>	line
%type	<code>	cmds
%type	<code>	cmd

%token	<numb>	NUM
%token	<boo>	BOOL
%token	<code>	PRINT
%token	<code>	TRUE
%token	<code>	FALSE
%token	<code>	FOR
%token	<code>	TO
%token	<code>	NEXT
%token	<code>	GOTO
%token	<code>	LET
%token	<code>	IF
%token	<code>	THEN
%token	<code>	NOT
%token	<code>	AND
%token	<code>	OR
%token	<code>	OPENBR
%token	<code>	CLOSEBR
%token	<vvar>	VAR
%token	<vvar>	STRVAR
%token	<str>	STRING

%left	'<' '>' '<=' '>=' '=' '<>'
%left	'+' '-' 
%left	'*' '/' '%'
%left	':'
%left	AND OR
%right	NOT

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
		PushAll($$, $1)
	}
|	line '\n' prog
	{
		NewCode(&$$)
		PushAll($$, $1)
		PushAll($$, $3)
	}

line:
	NUM cmds
	{
		NewCode(&$$)
		WriteCode($$, "line%d:\n", $1)
		PushAll($$, $2)
	}

cmds:
	cmd
	{
		NewCode(&$$)
		PushAll($$, $1)
	}
|	cmd ':' cmds
	{
		NewCode(&$$)
		PushAll($$, $1)
		PushAll($$, $3)
	}

cmd:
	printcmd
|	letnumcmd
|	letstrcmd
|	fortocmd
|	nextcmd
|	gotocmd
|	ifcmd
	{
		NewCode(&$$)
		PushAll($$, $1)
	}

letstrcmd:
	LET STRVAR '=' strexpr
	{
		if $4.state == STRING {
			NewCode(&$$)
			WriteCode($$, ".section .data\n")
			WriteCode($$, "str%s:\n", $2)
			WriteCode($$, "	.asciz \"%s\"\n", $4.str)
			WriteCode($$, ".section .text\n")
			// how to store a string?
		}
	}

letnumcmd:
	LET VAR '=' numexpr
	{
		NewCode(&$$)
		CreateNumVar($$, $2, 0)
		LoadNum($$, $4)
		WriteCode($$, "	ldr r1, =var%s\n", $2)
		WriteCode($$, "	str r0, [r1]\n")
	}

gotocmd:
	GOTO NUM
	{
		NewCode(&$$)
		WriteCode($$, "	bl line%d\n", $2)
	}

nextcmd:
	NEXT VAR
	{
		fmt.Println("NEXT")
		fornum := -1
		for e := forvars.Front(); e != nil; e = e.Next() {
			forvar := e.Value.(LoopInfo)
			if forvar.varname == $2 {
				fornum = forvar.forcount
			}
		}
		if fornum == -1 {
			fmt.Println("No loop for ", $2)
			os.Exit(5)
		}
		NewCode(&$$)
		WriteCode($$, "	ldr r1, =var%s\n", $2)
		WriteCode($$, "	ldr r0, [r1]\n")
		WriteCode($$, "	add r0, r0, #1\n")
		WriteCode($$, "	str r0, [r1]\n")
		WriteCode($$, "	b forlabel%d\n", fornum)
		WriteCode($$, "forend%d:\n", fornum)
	}

fortocmd:
	FOR VAR '=' numexpr TO numexpr
	{
		fmt.Println("FOR VAR = x to y:", $2, $4.numb, $6.numb)
		for e := forvars.Front(); e != nil; e = e.Next() {
			forvar := e.Value.(LoopInfo)
			if forvar.varname == $2 {
				fmt.Println("Already in a loop for ", $2)
				os.Exit(5)
			}
		}
		forcounter++
		forvars.PushBack(LoopInfo{
			$2,
			$4.numb,
			forcounter,
		})
		NewCode(&$$)
		WriteCode($$, ".section .data\n")
		if !Contains(numvars, $2) {
			WriteCode($$, "var%s:\n", $2)
			WriteCode($$, "	.word 0\n")
			numvars.PushBack($2)
		}
		WriteCode($$, "forlimit%d:\n", forcounter)
		WriteCode($$, "	.word 0\n")
		WriteCode($$, ".section .text\n")
		LoadNum($$, $4)
		WriteCode($$, "	ldr r1, =var%s\n", $2)
		WriteCode($$, "	str r0, [r1]\n")
		LoadNum($$, $6)
		WriteCode($$, "	ldr r1, =forlimit%d\n", forcounter)
		WriteCode($$, "	str r0, [r1]\n")
		WriteCode($$, "forlabel%d:\n", forcounter)
		WriteCode($$, "	ldr r1, =forlimit%d\n", forcounter)
		WriteCode($$, "	ldr r0, [r1]\n")
		WriteCode($$, "	ldr r1, =var%s\n", $2)
		WriteCode($$, "	ldr r2, [r1]\n")
		WriteCode($$, "	cmp r2, r0\n")
		WriteCode($$, "	bgt forend%d\n", forcounter)
	}

printcmd:
	PRINT numexpr
	{
		NewCode(&$$)
		if $2.state == NUM {
			WriteCode($$, "	ldr r0, =%d\n", $2.numb)
		} else {
			PushAll($$, $2)
		}
		WriteCode($$, "	bl doubledabble\n")
		WriteCode($$, "	bl println\n")
	}
|	PRINT boolexpr
	{
		NewCode(&$$)
		LoadBool($$, $2)
		WriteCode($$, "	bl printbool\n")
	}
|	PRINT strexpr
	{
		NewCode(&$$)
		if $2.state == STRING {
			varcounter += 1
			WriteCode($$, ".section .data\n")
			WriteCode($$, "str%d:\n", varcounter)
			WriteCode($$, "	.asciz \"%s\"\n", $2.str)
			WriteCode($$, ".section .text\n")
			WriteCode($$, "	ldr r0, =str%d\n", varcounter)
		} else {
			PushAll($$, $2)
		}
		WriteCode($$, "	bl println\n")
	}

ifcmd:
	IF boolexpr THEN cmd
	{
		NewCode(&$$)
		if $2.state == BOOL {
			if $2.boo {
				PushAll($$, $4)
			}
		} else {
			ifcounter += 1
			PushAll($$, $2)
			WriteCode($$, "	cmp r0, #0\n")
			WriteCode($$, "	beq ifend%d\n", ifcounter)
			PushAll($$, $4)
			WriteCode($$, "ifend%d:\n", ifcounter)
		}
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
		WriteCode($$, "	ldr r0, =str%s\n", $1)
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
				PushAll($$, $1)  // add whatever we have to something
			}
			if $3.state == STRING {
				// add something to STRING
			} else {
				PushAll($$, $3)
				WriteCode($$, "	mov r1, r0\n")
			}
			// add them somehow
		}
	}

// i think boolexpr will return a 1 or 0 for true and false
// or a BOOL
boolexpr:
	TRUE
	{
		fmt.Println("TRUE")
		$$.state = BOOL
		$$.boo = true
	}
|	FALSE
	{
		fmt.Println("FALSE")
		$$.state = BOOL
		$$.boo = false
	}
|	OPENBR boolexpr CLOSEBR
	{
		fmt.Println("( boolexpr )")
		NewCode(&$$)
		LoadPushBool($$, $2)
	}
|	numexpr '<' numexpr
	{
		fmt.Println("numexpr < numexpr")
		if $1.state == NUM && $3.state == NUM {
			$$.state = BOOL
			$$.boo = $1.numb < $3.numb
		} else {
			NewCode(&$$)
			LoadPushNum($$, $1)
			LoadNum($$, $3)
			PopNum($$, 1)
			WriteCode($$, "	cmp r1, r0\n")
			WriteCode($$, "	movlt r0, #1\n")
			WriteCode($$, "	movge r0, #0\n")
			PushNum($$, 0)
		}
	}
|	numexpr '>' numexpr
	{
		if $1.state == NUM && $3.state == NUM {
			$$.state = BOOL
			$$.boo = $1.numb > $3.numb
		} else {
			NewCode(&$$)
			LoadPushNum($$, $1)
			LoadNum($$, $3)
			PopNum($$, 1)
			WriteCode($$, "	cmp r1, r0\n")
			WriteCode($$, "	movgt r0, #1\n")
			WriteCode($$, "	movle r0, #0\n")
			PushNum($$, 0)
		}
	}
|	numexpr '>=' numexpr
	{
		if $1.state == NUM && $3.state == NUM {
			$$.state = BOOL
			$$.boo = $1.numb >= $3.numb
		} else {
			NewCode(&$$)
			LoadPushNum($$, $1)
			LoadNum($$, $3)
			PopNum($$, 1)
			WriteCode($$, "	cmp r1, r0\n")
			WriteCode($$, "	movge r0, #1\n")
			WriteCode($$, "	movlt r0, #0\n")
			PushNum($$, 0)
		}
	}
|	numexpr '<=' numexpr
	{
		if $1.state == NUM && $3.state == NUM {
			$$.state = BOOL
			$$.boo = $1.numb <= $3.numb
		} else {
			NewCode(&$$)
			LoadPushNum($$, $1)
			LoadNum($$, $3)
			PopNum($$, 1)
			WriteCode($$, "	cmp r1, r0\n")
			WriteCode($$, "	movge r0, #1\n")
			WriteCode($$, "	movlt r0, #0\n")
			PushNum($$, 0)
		}
	}
|	numexpr '<>' numexpr
	{
		if $1.state == NUM && $3.state == NUM {
			$$.state = BOOL
			$$.boo = $1.numb != $3.numb
		} else {
			NewCode(&$$)
			LoadPushNum($$, $1)
			LoadNum($$, $3)
			PopNum($$, 1)
			WriteCode($$, "	cmp r1, r0\n")
			WriteCode($$, "	movne r0, #1\n")
			WriteCode($$, "	moveq r0, #0\n")
			PushNum($$, 0)
		}
	}
|	numexpr '=' numexpr
	{
		if $1.state == NUM && $3.state == NUM {
			$$.state = BOOL
			$$.boo = $1.numb == $3.numb
		} else {
			NewCode(&$$)
			LoadPushNum($$, $1)
			LoadNum($$, $3)
			PopNum($$, 1)
			WriteCode($$, "	cmp r1, r0\n")
			WriteCode($$, "	moveq r0, #1\n")
			WriteCode($$, "	movne r0, #0\n")
			PushNum($$, 0)
		}
	}
|	boolexpr AND boolexpr
	{
		if $1.state == BOOL && $3.state == BOOL {
			$$.state = BOOL
			$$.boo = $1.boo && $3.boo
		} else {
			NewCode(&$$)
			LoadPushBool($$, $1)
			LoadBool($$, $3)
			PopNum($$, 1)
			WriteCode($$, "	and r0, r0, r1\n")
			PushNum($$, 0)
		}
	}
|	boolexpr OR boolexpr
	{
		if $1.state == BOOL && $3.state == BOOL {
			$$.state = BOOL
			$$.boo = $1.boo || $3.boo
		} else {
			NewCode(&$$)
			LoadPushBool($$, $1)
			LoadBool($$, $3)
			PopNum($$, 1)
			WriteCode($$, "	orr r0, r0, r1\n")
			PushNum($$, 0)
		}
	}
|	NOT boolexpr
	{
		if $2.state == BOOL {
			$$.state = BOOL
			$$.boo = !$2.boo
		} else {
			NewCode(&$$)
			PushAll($$, $2)
			PopNum($$, 0)
			WriteCode($$, "	mvn r0, r0\n")
			PushNum($$, 0)
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
		WriteCode($$, "	ldr r0, =var%s\n", $1)
		WriteCode($$, "	ldr r0, [r0]\n")
		PushNum($$, 0)
	}
|	numexpr '+' numexpr
	{
		if $1.state == NUM && $3.state == NUM {
			$$.state = NUM
			$$.numb = $1.numb + $3.numb
		} else {
			NewCode(&$$)
			LoadPushNum($$, $1)
			LoadNum($$, $3)
			PopNum($$, 1)
			WriteCode($$, "	add r0, r1, r0\n")
			PushNum($$, 0)
		}
	}
|	numexpr '*' numexpr
	{
		if $1.state == NUM && $3.state == NUM {
			$$.state = NUM
			$$.numb = $1.numb * $3.numb
		} else {
			NewCode(&$$)
			LoadPushNum($$, $1)
			LoadNum($$, $3)
			PopNum($$, 1)
 			WriteCode($$, "	mul r2, r0, r1\n")
 			PushNum($$, 2)
		}
	}
|	numexpr '/' numexpr
	{
		if $1.state == NUM && $3.state == NUM {
			$$.state = NUM
			$$.numb = $1.numb / $3.numb
		} else {
			NewCode(&$$)
			LoadPushNum($$, $1)
			LoadNum($$, $3)
			PopNum($$, 2)
			WriteCode($$, "	mov r1, r0\n")
			WriteCode($$, "	mov r0, r2\n")
 			WriteCode($$, "	bl intdiv\n")
 			PushNum($$, 0)
		}
	}
|	numexpr '%' numexpr
	{
		if $1.state == NUM && $3.state == NUM {
			$$.state = NUM
			$$.numb = $1.numb % $3.numb
		} else {
			NewCode(&$$)
			LoadPushNum($$, $1)
			LoadNum($$, $3)
			PopNum($$, 2)
			WriteCode($$, "	mov r1, r0\n")
			WriteCode($$, "	mov r0, r2\n")
 			WriteCode($$, "	bl intmod\n")
 			PushNum($$, 0)
		}
	}
|	numexpr '-' numexpr
	{
		if $1.state == NUM && $3.state == NUM {
			$$.state = NUM
			$$.numb = $1.numb - $3.numb
		} else {
			NewCode(&$$)
			LoadPushNum($$, $1)
			LoadNum($$, $3)
			PopNum($$, 1)
			WriteCode($$, "	sub r0, r1, r0\n")
 			PushNum($$, 0)
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
			return PRINT
		}
		if t == "TRUE" {
			return TRUE
		}
		if t == "FALSE" {
			return FALSE
		}
		if t == "AND" {
			return AND
		}
		if t == "OR" {
			return OR
		}
		if t == "NOT" {
			return NOT
		}
		if t == "GOTO" {
			return GOTO
		}
		if t == "LET" {
			return LET
		}
		if t == "FOR" {
			return FOR
		}
		if t == "IF" {
			return IF
		}
		if t == "THEN" {
			return THEN
		}
		if t == "TO" {
			return TO
		}
		if t == "NEXT" {
			return NEXT
		}
		if t == "(" {
			return OPENBR
		}
		if t == ")" {
			return CLOSEBR
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
	numvars = list.New()
	strvars = list.New()
	forvars = list.New()
	fmt.Println("Start")
	tok = 0
	varcounter = 0
	forcounter = 0
	ifcounter = 0

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
