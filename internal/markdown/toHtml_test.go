package markdown_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/floriankimmel/podflow/internal/markdown"
)

var _ = Describe("ToHtml", func() {
	It("converts markdown to html", func() {
		html := markdown.ToHTML("# Hello")
		Expect(html).To(Equal("<h1>Hello</h1>\n"))
	})

})
