package main

import (
	"bufio"
	"bytes"
	"container/list"
	"flag"
	"fmt"
	"io"
	"os"
	"regexp"
	"strconv"
	"strings"
)

// Read a whole file into the memory and store it as array of lines
func ReadLines(path string) (lines []string, err error) {
	var (
		file   *os.File
		part   []byte
		prefix bool
	)
	if file, err = os.Open(path); err != nil {
		return
	}
	defer file.Close()

	reader := bufio.NewReader(file)
	buffer := bytes.NewBuffer(make([]byte, 0))
	for {
		if part, prefix, err = reader.ReadLine(); err != nil {
			break
		}
		buffer.Write(part)
		if !prefix {
			lines = append(lines, buffer.String())
			buffer.Reset()
		}
	}
	if err == io.EOF {
		err = nil
	}
	return
}

func PrintIntVar(file *os.File, varname string) {
	file.WriteString(fmt.Sprintf(
		`	ldr	r1, =intvar%s
	ldr	r0, [r1]
	bl	doubledabble
	bl	print
`, varname))
}

func DeclareIntVar(file *os.File, name string, value int) {
	intvars.PushBack(name)
	file.WriteString(fmt.Sprintf(
		`	ldr	r0, =intvar%s
	ldr	r1, =%d
	str	r1, [r0]
`, name, value))
}

func WriteHeader(file *os.File) {
	file.WriteString(
		`@filename: prog.S
.text
.align 2
.global _start
_start:
`)
}

func WriteEnd(file *os.File) {
	file.WriteString(
		`@end
	mov	r0, #0
	mov	r7, #1
	svc	0x00000000
`)
}

func WriteLib(file *os.File) {
	file.WriteString(
		`print:
	push	{r7}
	mov	r2, #0
printloop: 
	ldrb	r1, [r0, r2]
	cmp	r1, #0
	addne	r2, r2, #1
	bne	printloop
	mov	r1, r0
	mov	r0, #1
	mov	r7, #4
	svc	0x00000000
	pop	{r7}
	bx	lr
`)
}

func WriteStrings(file *os.File) {
	file.WriteString(
		`.align 2
.section .data
linebreak:
	.asciz "\n"
`)
	for key, value := range stringlist {
		file.WriteString(fmt.Sprintf(
			`string%s:
	.asciz %s
`, key, value))
	}
}

func WriteVars(file *os.File) {
	for el := intvars.Front(); el != nil; el = el.Next() {
		file.WriteString(fmt.Sprintf(
			`intvar%s:
	.word	0
`, el.Value))
	}
}

func CheckError(err error) bool {
	if err != nil {
		fmt.Printf("Error: %s\n", err)
		return true
	}
	return false
}

type LoopInfo struct {
	varname string
	limit   int
	linenum string
}

var stringlist map[string]string
var intvars *list.List
var stringvars *list.List
var fors map[string]LoopInfo

func Usage() {
	fmt.Fprintf(os.Stderr, "Usage: %s [inputfile]\n", os.Args[0])
	flag.PrintDefaults()
	os.Exit(2)
}

func CompileRegExp(restring string) *regexp.Regexp {
	re, err := regexp.Compile(restring)
	if CheckError(err) {
		os.Exit(1)
	}
	return re
}

func main() {
	stringlist = make(map[string]string)
	intvars = list.New()
	stringvars = list.New()
	fors = make(map[string]LoopInfo)

	fmt.Println("GOBASIC")

	flag.Usage = Usage
	flag.Parse()

	args := flag.Args()
	if len(args) < 1 {
		fmt.Println("Input file missing")
		os.Exit(1)
	}
	filename := args[0]

	lines, err := ReadLines(filename)
	if CheckError(err) {
		return
	}
	var file *os.File
	if file, err = os.Create(strings.Replace(filename, ".bas", ".S", 1)); err != nil {
		fmt.Println("Error: %s\n", err)
		return
	}
	defer file.Close()
	WriteHeader(file)
	lineRE := CompileRegExp(`([0-9]+) .*`)
	printRE := CompileRegExp(`[0-9]+\s+PRINT\s+"([^"]*)"(;?)\s*`)
	printNumRE := CompileRegExp(`[0-9]+\s+PRINT\s+([0-9]+)(;?)\s*`)
	printIntVarRE := CompileRegExp(`[0-9]+\s+PRINT\s+([A-Za-z_]+)(;?)\s*`)
	gotoRE := CompileRegExp(`[0-9]+\s+GOTO\s+([0-9]+)\s*`)
	letIntRE := CompileRegExp(`[0-9]+\s+LET\s+([A-Z][A-Z0-9_]*)\s*=\s*([0-9]+)\s*`)
	letStringRE := CompileRegExp(`[0-9]+\s+LET\s+([A-Z][A-Z0-9_]*$)\s*=\s*([0-9]+)\s*`)
	forToRE := CompileRegExp(`[0-9]+\s+FOR\s+([A-Z][A-Z0-9_]*)\s*=\s*([0-9]+)\s*TO\s*([0-9]+)\s*`)
	nextRE := CompileRegExp(`[0-9]+\s+NEXT\s+([A-Z][A-Z0-9_]*)\s*`)

	for _, line := range lines {
		if lineRE.MatchString(line) {
			linenum := lineRE.FindStringSubmatch(line)[1]
			file.WriteString(fmt.Sprintf(
				"line%s:				@ %s\n", linenum, line))
			switch {
			case printRE.MatchString(line):
				str := strconv.QuoteToASCII(printRE.FindStringSubmatch(line)[1])
				if printRE.FindStringSubmatch(line)[2] != ";" {
					stringlist[linenum] = str[:len(str)-1] + "\\n\""
				} else {
					stringlist[linenum] = str
				}
				file.WriteString(fmt.Sprintf(
					`	ldr	r0, =string%s
	bl	print
`, linenum))
			case printNumRE.MatchString(line):
				num := printNumRE.FindStringSubmatch(line)[1]
				if printNumRE.FindStringSubmatch(line)[2] != ";" {
					stringlist[linenum] = fmt.Sprintf(`"%s\n"`, num)
				} else {
					stringlist[linenum] = fmt.Sprintf(`"%s"`, num)
				}
				file.WriteString(fmt.Sprintf(
					`	ldr	r0, =string%s
	bl	print
`, linenum))
			case printIntVarRE.MatchString(line):
				varname := printIntVarRE.FindStringSubmatch(line)[1]
				PrintIntVar(file, varname)
				if printIntVarRE.FindStringSubmatch(line)[2] != ";" {
					file.WriteString(`	ldr	r0, =linebreak
	bl	print
`)
				}
			case gotoRE.MatchString(line):
				gotonum := gotoRE.FindStringSubmatch(line)[1]
				file.WriteString(fmt.Sprintf(
					"	b	line%s\n", gotonum))
			case letIntRE.MatchString(line):
				varname := letIntRE.FindStringSubmatch(line)[1]
				varval := letIntRE.FindStringSubmatch(line)[2]
				value, err := strconv.Atoi(varval)
				if err != nil {
					fmt.Printf("Syntax error on line %n\n", linenum)
					os.Exit(1)
				}
				DeclareIntVar(file, varname, value)
			case letStringRE.MatchString(line):
			case forToRE.MatchString(line):
				start, err := strconv.Atoi(forToRE.FindStringSubmatch(line)[2])
				if err != nil {
					fmt.Printf("Syntax error on line %n\n", linenum)
					os.Exit(1)
				}
				limit, err := strconv.Atoi(forToRE.FindStringSubmatch(line)[3])
				if err != nil {
					fmt.Printf("Syntax error on line %n\n", linenum)
					os.Exit(1)
				}
				loopinfo := LoopInfo{
					forToRE.FindStringSubmatch(line)[1],
					limit,
					linenum,
				}
				fors[loopinfo.varname] = loopinfo
				DeclareIntVar(file, loopinfo.varname, start)
				file.WriteString(fmt.Sprintf(
					"for%s:\n", linenum))
			case nextRE.MatchString(line):
				varname := nextRE.FindStringSubmatch(line)[1]
				if loopinfo, exists := fors[varname]; exists {
					file.WriteString(fmt.Sprintf(
						`	ldr	r2, =intvar%s
	ldr	r1, [r2]
	ldr	r0, =%d
	cmp	r0, r1
	addne	r1, r1, #1
	strne	r1, [r2]
	bne	for%s
`, loopinfo.varname, loopinfo.limit, loopinfo.linenum))
				}
			default:
				fmt.Println("Syntax error")
				os.Exit(1)
			}
		}
		fmt.Println(line)
	}
	WriteEnd(file)
	WriteLib(file)
	WriteStrings(file)
	WriteVars(file)
}
