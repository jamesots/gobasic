package main

import (
	"bufio"
	"bytes"
	"flag"
	"fmt"
	"io"
	"os"
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

func WriteHeader(file *os.File) {
	file.WriteString(
		`@filename: prog.S
.text
.align 2
.global _start
_start:
`)
}

func WriteEnd(code Code) {
	WriteCode(code, "end:\n")
	WriteCode(code, "	mov	r0, #0\n")
	WriteCode(code, "	mov	r7, #1\n")
	WriteCode(code, "	svc	0x00000000\n")
}

func CheckError(err error) bool {
	if err != nil {
		fmt.Printf("Error: %s\n", err)
		return true
	}
	return false
}

func Usage() {
	fmt.Fprintf(os.Stderr, "Usage: %s [inputfile]\n", os.Args[0])
	flag.PrintDefaults()
	os.Exit(2)
}

func main() {
	fmt.Println("GOBASIC")

	flag.Usage = Usage
	flag.Parse()

	args := flag.Args()
	if len(args) < 1 {
		fmt.Println("Input file missing")
		os.Exit(1)
	}
	filename := args[0]

	var err error
	var file *os.File
	if file, err = os.Create(strings.Replace(filename, ".bas", ".S", 1)); err != nil {
		fmt.Println("Error: %s\n", err)
		return
	}
	defer file.Close()
	WriteHeader(file)

	toks, err := Tokenise(filename)
	
	Parse(toks)
	CleanPushPop(result)
	WriteEnd(result)
	PrintAll(file, result)
}
