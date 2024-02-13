package markdown

import (
	convert "github.com/russross/blackfriday/v2"
)

func ToHTML(markdown string) string {
	return string(convert.Run([]byte(markdown)))
}
