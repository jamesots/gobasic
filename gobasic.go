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
)

// Read a whole file into the memory and store it as array of lines
func readLines(path string) (lines []string, err error) {
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

func writeHeader(file *os.File) {
	file.WriteString("@filename: prog.S\n" +
		".text\n" +
		".align 2\n" +
		".global _start\n" + 
		"_start:\n")
}

func writeEnd(file *os.File) {
	file.WriteString("	mov	r0, #0\n" + 
		"	mov	r7, #1\n" + 
		"	svc	0x00000000\n")
}

func writeLib(file *os.File) {
	file.WriteString("print:\n" +
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
		"	bx	lr\n")
}

func writeStrings(file *os.File) {
	file.WriteString(".align 2\n" +
		".section .data\n")
	for key, value := range stringlist {
		file.WriteString(fmt.Sprintf("string%s:\n" +
			"	.asciz \"%s\"\n", key, value))
	}
}

func checkerr(err error) bool {
	if err != nil {
		fmt.Println("Error: %s\n", err)
		return true
	}
	return false
}

var stringlist map[string]string

func usage() {
	fmt.Fprintf(os.Stderr, "usage: %s [inputfile]\n", os.Args[0])
	flag.PrintDefaults()
	os.Exit(2)
}

func main() {
	stringlist = make(map[string]string)

	fmt.Println("BASIC")

	flag.Usage = usage
	flag.Parse()

	args := flag.Args()
	if len(args) < 1 {
		fmt.Println("Input file missing")
		os.Exit(1)
	}
	filename := args[0]

	lines, err := readLines(filename)
	if checkerr(err) {
		return
	}
	var file *os.File
	if file, err = os.Create(strings.Replace(filename, ".bas", ".S", 1)); err != nil {
		fmt.Println("Error: %s\n", err)
		return
	}
	defer file.Close()
	writeHeader(file);
	re, err := regexp.Compile("([0-9]+) .*")
	if checkerr(err) {
		return
	}
	printre, err := regexp.Compile("[0-9]+\\s+PRINT\\s+\"([^\"]*)\"(;?)\\s*")
	if checkerr(err) {
		return
	}
	gotore, err := regexp.Compile("[0-9]+\\s+GOTO\\s+([0-9]+)\\s*")
	for _, line := range lines {
		if re.MatchString(line) {
			num := re.FindStringSubmatch(line)[1]
			file.WriteString(fmt.Sprintf("line%s:\n", num))
			if printre.MatchString(line) {
				if printre.FindStringSubmatch(line)[2] != ";" {
					stringlist[num] = fmt.Sprintf("%s\\n", printre.FindStringSubmatch(line)[1])
				} else {
					stringlist[num] = printre.FindStringSubmatch(line)[1]
				}
				file.WriteString(fmt.Sprintf("	ldr	r0, =string%s\n" +
					"	bl	print\n", num))
			} else if gotore.MatchString(line) {
				gotonum := gotore.FindStringSubmatch(line)[1]
				file.WriteString(fmt.Sprintf("	b	line%s\n", gotonum))
			}
		}
		fmt.Println(line)
	}
	writeEnd(file);
	writeLib(file);
	writeStrings(file);
}
