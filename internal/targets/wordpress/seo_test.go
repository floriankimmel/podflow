package wordpress_test

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sort"
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/floriankimmel/podflow/internal/targets/wordpress"
)

// The same fixtures pin the app's and the plugin's reading of seo.md.
var seoFixtures = filepath.Join("..", "..", "..", "desktop", "Tests", "fixtures", "seo")

var _ = Describe("SEO texts", func() {
	It("are read from seo.md as the shared fixtures expect", func() {
		raw, err := os.ReadFile(filepath.Join(seoFixtures, "expected.json"))
		Expect(err).ToNot(HaveOccurred())
		var expected map[string]map[string]string
		Expect(json.Unmarshal(raw, &expected)).To(Succeed())
		Expect(expected).ToNot(BeEmpty())

		names := make([]string, 0, len(expected))
		for name := range expected {
			names = append(names, name)
		}
		sort.Strings(names)
		for _, name := range names {
			markdown, err := os.ReadFile(filepath.Join(seoFixtures, name))
			Expect(err).ToNot(HaveOccurred())
			sections := wordpress.SEOSections(string(markdown))
			for label, want := range expected[name] {
				Expect(sections[label]).To(Equal(want), "%s: %s", name, label)
			}
		}
	})

	It("reads CRLF files like LF files", func() {
		markdown, err := os.ReadFile(filepath.Join(seoFixtures, "full.md"))
		Expect(err).ToNot(HaveOccurred())
		crlf := strings.ReplaceAll(string(markdown), "\n", "\r\n")
		Expect(wordpress.SEOSections(crlf)).To(Equal(wordpress.SEOSections(string(markdown))))
	})

	It("does not take the next label as the text of an empty section", func() {
		sections := wordpress.SEOSections("**Focus Keywords:**\n\n**Facebook OG Title:**\nTitel\n")
		Expect(sections["Focus Keywords"]).To(BeEmpty())
		Expect(sections["Facebook OG Title"]).To(Equal("Titel"))
	})
})
