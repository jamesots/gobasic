package main

import (
	"os"
	"fmt"
	"regexp"
	"container/list"
)	

func Contains(l *list.List, item interface{}) bool {
	for e := l.Front(); e != nil; e = e.Next() {
		if e.Value == item {
			return true
		}
	}
	return false
}

func PushAll(to Code, from Code) {
	for e := from.code.Front(); e != nil; e = e.Next() {
		to.code.PushBack(e.Value)
	}
	for e := from.data.Front(); e != nil; e = e.Next() {
		to.data.PushBack(e.Value)
	}
}

func PrintAll(file *os.File, from Code) {
	if from.code == nil || from.data == nil {
		return
	}
	for e := from.code.Front(); e != nil; e = e.Next() {
		var s = e.Value.(string)
		file.WriteString(s)
	}
	file.WriteString(".section .data\n")
	for e := from.data.Front(); e != nil; e = e.Next() {
		var s = e.Value.(string)
		file.WriteString(s)
	}
	file.WriteString(".section .text\n")
}

func WriteData(code Code, format string, a ...interface{}) {
	res := fmt.Sprintf(format, a...)
	code.data.PushBack(res)
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
		WriteData(to, "var%s:\n", varname)
		WriteData(to, "	.word %d\n", val)
		numvars.PushBack(varname)
	}
}

func PushNum(to Code, reg int) {
	WriteCode(to, "	push {r%d}\n", reg)
}

func PopNum(to Code, reg int) {
	WriteCode(to, "	pop {r%d}\n", reg)
}

func CleanPushPop(code Code) {
	// removes pointless successive pushes and pops
	fmt.Println("Cleaning up")
	popRe, _ := regexp.Compile("	pop \\{r([0-9]+)\\}\n")
	pushRe, _ := regexp.Compile("	push \\{r([0-9]+)\\}\n")
	var lastpush string = ""
	var lastel *list.Element
	if code.code == nil {
		return
	}
	for e := code.code.Front(); e != nil; e = e.Next() {
		if (e.Value != nil) {
			s := e.Value.(string)
			if popRe.MatchString(s) {
				reg := popRe.FindStringSubmatch(s)[1]
				if lastpush == reg {
					el := e.Next()
					code.code.Remove(e)
					code.code.Remove(lastel)
					e = el.Prev()
					lastpush = ""
				}
			} else if pushRe.MatchString(s) {
				lastpush = pushRe.FindStringSubmatch(s)[1]
				lastel = e
			}
		}
	}
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
		PopNum(to, 0)
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
	code.data = list.New()
}
