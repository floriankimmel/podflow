package targets

import (
	"fmt"
	"io"
	"os"

	"golang.org/x/term"
)

type ProgressReader struct {
	reader io.ReadSeeker
	total  int64
	read   int64
}

func (pr *ProgressReader) Seek(offset int64, whence int) (int64, error) {
	newOffset, err := pr.reader.Seek(offset, whence)
	if err == nil {
		pr.read = newOffset
	}
	return newOffset, err
}

func (pr *ProgressReader) Read(p []byte) (int, error) {
	n, err := pr.reader.Read(p)
	pr.read += int64(n)

	if err == nil {
		percentage := float64(pr.read) / float64(pr.total) * 100
		width, _, _ := term.GetSize(int(os.Stdout.Fd()))
		format := fmt.Sprintf("\r%%-%ds", width)

		fmt.Printf(format, fmt.Sprintf("Progress: %.2f%%", percentage))
	}

	return n, err
}
