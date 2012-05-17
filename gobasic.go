package main

import (
	"fmt"
	"bufio"
	"os"
	"io"
	"bytes"
	"regexp"
	"flag"
	"strings"
	"container/list"
	"strconv"
)

// Read a whole file into the memory and store it as array of lines
func ReadLines(path string) (lines []string, err error) {
    var (
        file *os.File
        part []byte
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

func DeclareIntVar(file *os.File, name string, value int) {
	intvars.PushBack(name)
	file.WriteString(fmt.Sprintf(
		"	ldr	r0, =intvar%s\n" +
		"	ldr	r1, =%d\n" +
		"	str	r1, [r0]\n", name, value))
}

func WriteHeader(file *os.File) {
	file.WriteString(
		"@filename: prog.S\n" +
		".text\n" +
		".align 2\n" +
		".global _start\n" + 
		"_start:\n")
}

func WriteEnd(file *os.File) {
	file.WriteString(
		"@end\n" +
		"	mov	r0, #0\n" + 
		"	mov	r7, #1\n" + 
		"	svc	0x00000000\n")
}

func WriteLib(file *os.File) {
	file.WriteString(
		"print:\n" +
		"	push	{r7}\n" +
		"	mov	r2, #0\n" +
		"printloop:\n" + 
		"	ldrb	r1, [r0, r2]\n" +
		"	cmp	r1, #0\n" +
		"	addne	r2, r2, #1\n" +
		"	bne	printloop\n" +
		"	mov	r1, r0\n" +
		"	mov	r0, #1\n" +
		"	mov	r7, #4\n" +
		"	svc	0x00000000\n" +
		"	pop	{r7}\n" +
		"	bx	lr\n")
}

func WriteStrings(file *os.File) {
	file.WriteString(
		".align 2\n" +
		".section .data\n")
	for key, value := range stringlist {
		file.WriteString(fmt.Sprintf(
			"string%s:\n" +
			"	.asciz \"%s\"\n", key, value))
	}
}

func WriteVars(file *os.File) {
	for el := intvars.Front(); el != nil; el = el.Next() {
		file.WriteString(fmt.Sprintf(
			"intvar%s:\n" +
			"	.word	0\n", el.Value))
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
	limit int
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
	WriteHeader(file);
	lineRE := CompileRegExp("([0-9]+) .*")
	printRE := CompileRegExp("[0-9]+\\s+PRINT\\s+\"([^\"]*)\"(;?)\\s*")
	gotoRE := CompileRegExp("[0-9]+\\s+GOTO\\s+([0-9]+)\\s*")
	letIntRE := CompileRegExp("[0-9]+\\s+LET\\s+([A-Z][A-Z0-9_]*)\\s*=\\s*([0-9]+)\\s*")
	letStringRE := CompileRegExp("[0-9]+\\s+LET\\s+([A-Z][A-Z0-9_]*$)\\s*=\\s*([0-9]+)\\s*")
	forToRE := CompileRegExp("[0-9]+\\s+FOR\\s+([A-Z][A-Z0-9_]*)\\s*=\\s*([0-9]+)\\s*TO\\s*([0-9]+)\\s*")
	nextRE := CompileRegExp("[0-9]+\\s+NEXT\\s+([A-Z][A-Z0-9_]*)\\s*")
	
	for _, line := range lines {
		if lineRE.MatchString(line) {
			linenum := lineRE.FindStringSubmatch(line)[1]
			file.WriteString(fmt.Sprintf(
				"line%s:				@ %s\n", linenum, line))
			switch {
			case printRE.MatchString(line):
				if printRE.FindStringSubmatch(line)[2] != ";" {
					stringlist[linenum] = fmt.Sprintf("%s\\n", printRE.FindStringSubmatch(line)[1])
				} else {
					stringlist[linenum] = printRE.FindStringSubmatch(line)[1]
				}
				file.WriteString(fmt.Sprintf(
					"	ldr	r0, =string%s\n" +
					"	bl	print\n", linenum))
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
				// define a variable if it doesn't already exist
				// store a label for where this loop starts
				// store the upperlimit
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
			case nextRE.MatchString(line):
				// check if variable exists
				// increment variable
				// check if variable has hit limit
				// if not, jump to start
				// otherwise, remove loop from map
				varname := nextRE.FindStringSubmatch(line)[1]
				if loopinfo, exists := fors[varname]; exists {
					file.WriteString(fmt.Sprintf(
						"	ldr	r0, =intvar%s\n" +
						"	ldr	r1, [r0]\n" +
						"	add	r1, r1, #1\n" +
						"	str r1, [r0]\n" +
						"	mov r0, #%d\n" + // do i need a ldr here?
						"	cmp	r0, r1\n" +
						"	bne	line%s\n", loopinfo.varname, loopinfo.limit, loopinfo.linenum))
				}
			default:
				fmt.Println("Syntax error")
				os.Exit(1)
			}
		}
		fmt.Println(line)
	}
	WriteEnd(file);
	WriteLib(file);
	WriteStrings(file);
	WriteVars(file);
}
