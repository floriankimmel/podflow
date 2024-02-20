package input

import (
	"github.com/chzyer/readline"
)

type Input interface {
	Text(prompt string) string
}

type Stdin struct {
}

func (stdin Stdin) Text(prompt string) string {
	rl, err := readline.New(prompt)
	if err != nil {
		panic(err)
	}
	defer rl.Close()

	line, _ := rl.Readline()
	return line
}
