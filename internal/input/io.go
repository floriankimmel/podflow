package input

import (
	"bufio"
	"os"
)

type Input interface {
	Text() string
}

type Stdin struct {
}

func (stdin Stdin) Text() string {
	scanner := bufio.NewScanner(os.Stdin)
	scanner.Scan()
	return scanner.Text()
}
