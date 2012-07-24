package main

import (
	"bufio"
	"bytes"
	"container/list"
	"fmt"
	"os"
)

var toks *list.List

type Token struct {
	text      string
	tokentype int
}

func NextTok(tok *bytes.Buffer, tokentype int) {
	if tok.Len() > 0 {
		//		fmt.Println(tok.String())
		toks.PushBack(Token{
			tok.String(),
			tokentype})
		tok.Truncate(0)
	}
}

const (
	TOK_STRING int = iota + 1
	TOK_NUMBER
	TOK_SYMBOL
	TOK_NEWLINE
	TOK_IDENTIFIER
)

func Tokenise(filename string) (*list.List, error) {
	var err error

	var infile *os.File
	if infile, err = os.Open(filename); err != nil {
		return nil, err
	}
	defer infile.Close()

	reader := bufio.NewReader(infile)

	toks = list.New()
	var tok bytes.Buffer
	var state int = TOK_IDENTIFIER
	for {
		c, _, err := reader.ReadRune()
		if err != nil {
			break
		}

		if c == '\n' {
			NextTok(&tok, state)
			tok.WriteString("**NEWLINE**")
			NextTok(&tok, TOK_NEWLINE)
			state = TOK_IDENTIFIER
			continue
		}

		if state == TOK_IDENTIFIER {
			if c >= '0' && c <= '9' {
				reader.UnreadRune()
				NextTok(&tok, state)
				state = TOK_NUMBER
			} else if c == '"' {
				NextTok(&tok, state)
				state = TOK_STRING
			} else if c == ' ' || c == '\t' {
				NextTok(&tok, state)
			} else if c == '$' {
				tok.WriteRune(c)
				NextTok(&tok, state)
			} else if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') {
				tok.WriteRune(c)
			} else {
				reader.UnreadRune()
				NextTok(&tok, state)
				state = TOK_SYMBOL
			}
		} else if state == TOK_SYMBOL {
			if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '"' {
				reader.UnreadRune()
				NextTok(&tok, state)
				state = TOK_IDENTIFIER
			} else if c == ' ' || c == '\t' {
				NextTok(&tok, state)
			} else {
				tok.WriteRune(c)
				s := tok.String()
				if s == "(" || s == ")" {
					NextTok(&tok, state)
				}
			}
		} else if state == TOK_NUMBER {
			if c >= '0' && c <= '9' {
				tok.WriteRune(c)
			} else {
				reader.UnreadRune()
				NextTok(&tok, state)
				state = TOK_IDENTIFIER
			}
		} else if state == TOK_STRING {
			if c != '"' {
				tok.WriteRune(c)
			} else {
				NextTok(&tok, state)
				state = TOK_IDENTIFIER
			}
		}
	}
	NextTok(&tok, state)

	for e := toks.Front(); e != nil; e = e.Next() {
		var s = e.Value.(Token)
		fmt.Println(s.text, s.tokentype)
	}

	return toks, nil
}
