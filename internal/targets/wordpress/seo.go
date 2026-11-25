package wordpress

import "strings"

// SEOSections reads seo.md: each "**<Label>:**" line starts a section that
// runs to the next label. Labels may be indented, ``` fence lines and CR line
// endings are ignored, text before the first label is skipped, and section
// text is trimmed.
//
// The app (ContentParser.seoSections) and the plugin (seo.sh) read the same
// grammar; the shared fixtures in desktop/Tests/fixtures/seo pin all three.
func SEOSections(markdown string) map[string]string {
	sections := map[string]string{}
	label := ""
	var lines []string
	inSection := false
	flush := func() {
		if inSection {
			sections[label] = strings.TrimSpace(strings.Join(lines, "\n"))
		}
	}
	for _, line := range strings.Split(strings.ReplaceAll(markdown, "\r", ""), "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "```") {
			continue
		}
		if len(trimmed) > 5 && strings.HasPrefix(trimmed, "**") && strings.HasSuffix(trimmed, ":**") {
			flush()
			label, lines, inSection = trimmed[2:len(trimmed)-3], nil, true
			continue
		}
		if inSection {
			lines = append(lines, line)
		}
	}
	flush()
	return sections
}
