package main

import (
	"bufio"
	"bytes"
//	"container/list"
	"flag"
	"fmt"
	"io"
	"os"
//	"regexp"
//	"strconv"
	"strings"
)

var strs []string

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

func NextTok(tok *bytes.Buffer) {
	if tok.Len() > 0 {
		fmt.Println(tok.String())
		tok.Truncate(0)
	}
}

func main() {
	var err error
	fmt.Println("GOBASIC Tokeniser")

	flag.Usage = Usage
	flag.Parse()

	args := flag.Args()
	if len(args) < 1 {
		fmt.Println("Input file missing")
		os.Exit(1)
	}
	filename := args[0]

	var infile *os.File
	if infile, err = os.Open(filename); err != nil {
		return
	}
	defer infile.Close()

	reader := bufio.NewReader(infile)
	var file *os.File
	if file, err = os.Create(strings.Replace(filename, ".bas", ".S", 1)); err != nil {
		fmt.Println("Error: %s\n", err)
		return
	}
	defer file.Close()

	var tok bytes.Buffer
	const (
		NORMAL int = iota+1
		STRING
		NUMBER
	)
	var state int = NORMAL
	for {
		c, _, err := reader.ReadRune()
		if err != nil {
			return
		}
		if state == NORMAL {
			if c >= '0' && c <= '9' {
				state = NUMBER
				reader.UnreadRune()
				NextTok(&tok)
			} else if c == '"' {
				state = STRING
				NextTok(&tok)
			} else if (c == '\n' || c == ' ' || c == '\t') {
				NextTok(&tok)
			} else {
				tok.WriteRune(c)
			}
		} else if state == NUMBER {
			if c >= '0' && c <= '9' {
				tok.WriteRune(c)
			} else {
				state = NORMAL
				reader.UnreadRune()
				NextTok(&tok)
			}
		} else if state == STRING {
			if c != '"' {
				tok.WriteRune(c)
			} else {
				state = NORMAL
				NextTok(&tok)
			}
		}
	}
}
