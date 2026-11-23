#!/bin/bash
# Print one section of seo.md (the block after "**<Label>:**" up to the next
# "**...:**" label), trimmed.
#
#   seo.sh "<Label>" [file]      e.g. seo.sh "YouTube Beschreibung" seo.md
#
# Same reading as the app's ContentParser.seoSections: labels may be indented,
# ``` fence lines and CR line endings are ignored, text before the first label
# is skipped. Shared fixtures in Tests/fixtures/seo pin both.
set -euo pipefail

label="$1"
file="${2:-seo.md}"

tr -d '\r' < "$file" | sed -e '/^[[:space:]]*```/d' | awk -v label="**${label}:**" '
  { line = $0; sub(/^[[:space:]]+/, "", line) }
  line ~ /^\*\*[^*]+:\*\*[[:space:]]*$/ { capture = (index(line, label) == 1); next }
  capture { print }
' | awk '
  { lines[NR] = $0 }
  END {
    start = 1; end = NR
    while (start <= end && lines[start] ~ /^[[:space:]]*$/) start++
    while (end >= start && lines[end] ~ /^[[:space:]]*$/) end--
    if (start > end) exit
    sub(/^[[:space:]]+/, "", lines[start])
    sub(/[[:space:]]+$/, "", lines[end])
    for (i = start; i <= end; i++) print lines[i]
  }'
