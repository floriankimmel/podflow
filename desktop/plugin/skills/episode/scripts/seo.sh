#!/bin/bash
# Print one section of seo.md (the block after "**<Label>:**" up to the next
# "**...:**" label), trimmed.
#
#   seo.sh "<Label>" [file]      e.g. seo.sh "YouTube Beschreibung" seo.md
set -euo pipefail

label="$1"
file="${2:-seo.md}"

awk -v label="**${label}:**" '
  /^\*\*[^*]+:\*\*[[:space:]]*$/ { capture = ($0 ~ /^[[:space:]]*/ && index($0, label) == 1); next }
  capture { print }
' "$file" | sed -e '/^```/d' | awk '
  { lines[NR] = $0 }
  END {
    start = 1; end = NR
    while (start <= end && lines[start] ~ /^[[:space:]]*$/) start++
    while (end >= start && lines[end] ~ /^[[:space:]]*$/) end--
    for (i = start; i <= end; i++) print lines[i]
  }'
