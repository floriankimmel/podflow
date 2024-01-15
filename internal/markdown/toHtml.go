package markdown

import (
	convert "github.com/russross/blackfriday/v2"
)

func ToHtml(markdown string) string {
    return string(convert.Run([]byte(markdown)))
}

