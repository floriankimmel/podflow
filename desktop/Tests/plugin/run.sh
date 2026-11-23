#!/bin/bash
# Script tests for the podflow plugin (state.sh, seo.sh, auphonic.sh against a stub).
# Usage: plugin/tests/run.sh   (needs python3 for the stub server)
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$HERE/../../plugin/skills/episode/scripts"
WORK="$(mktemp -d)"
PORT=18473
fails=0

check() { # check <name> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1"; echo "  expected: $2"; echo "  actual:   $3"; fails=$((fails + 1)); fi
}

cd "$WORK"

# --- state.sh ---
echo '{"number":"371","title":"Testfolge","type":"compilation","steps":{}}' > state.json
check "state default pending" "pending" "$(bash "$SCRIPTS/state.sh" get auphonic_create)"
bash "$SCRIPTS/state.sh" set auphonic_create in_progress
bash "$SCRIPTS/state.sh" put auphonic_create uuid UUID1
bash "$SCRIPTS/state.sh" set auphonic_create done
check "state done" "done" "$(bash "$SCRIPTS/state.sh" get auphonic_create)"
check "state data survives set" "UUID1" "$(bash "$SCRIPTS/state.sh" data auphonic_create uuid)"
bash "$SCRIPTS/state.sh" set transcript failed "kein Transkript"
check "state error stored" "kein Transkript" "$(jq -r .steps.transcript.error state.json)"
bash "$SCRIPTS/state.sh" set transcript done
check "state error cleared" "null" "$(jq -r .steps.transcript.error state.json)"
check "state field" "Testfolge" "$(bash "$SCRIPTS/state.sh" field title)"
bash "$SCRIPTS/state.sh" set x bogus 2>/dev/null; check "state rejects bad status" "2" "$?"

# --- seo.sh ---
cat > seo.md <<'SEO'
**Title Tag:**
Marathon Training – Folge 371 | Laufendentdecken Podcast

**Meta-Description:**
Wie wir uns auf den Marathon vorbereiten. Jetzt anhören.

**Focus Keywords:**
marathon, training, trainingsplan

**YouTube Titel:**
Marathon Training: Unser Plan

**YouTube Beschreibung:**
Erste Zeile.

- Punkt eins
- Punkt zwei

https://laufendentdecken-podcast.at/371

**YouTube Tags:**
laufen, marathon , podcast
SEO
check "seo single line" "Marathon Training: Unser Plan" "$(bash "$SCRIPTS/seo.sh" "YouTube Titel" seo.md)"
check "seo multi line" "6" "$(bash "$SCRIPTS/seo.sh" "YouTube Beschreibung" seo.md | wc -l | tr -d ' ')"
check "seo last line" "https://laufendentdecken-podcast.at/371" "$(bash "$SCRIPTS/seo.sh" "YouTube Beschreibung" seo.md | tail -1)"
check "seo missing label empty" "" "$(bash "$SCRIPTS/seo.sh" "Gibt es nicht" seo.md)"

# --- auphonic.sh against stub ---
LOG="$WORK/requests.log"; : > "$LOG"
python3 "$HERE/stub_auphonic.py" "$PORT" "$LOG" &
STUB=$!
trap 'kill $STUB 2>/dev/null; rm -rf "$WORK"' EXIT
for _ in 1 2 3 4 5 6 7 8 9 10; do curl -s -o /dev/null "http://127.0.0.1:$PORT/" && break; sleep 0.3; done

export AUPHONIC_BASE="http://127.0.0.1:$PORT" AUPHONIC_API_KEY="k" AUPHONIC_PRESET="PRESET1" AUPHONIC_POLL_SECONDS=1
A="$SCRIPTS/auphonic.sh"
echo "video" > video.mp4

check "create prints uuid" "UUID1" "$(bash "$A" create "LEP#371 - Test" "371_test")"
check "create held for review" "true" "$(jq -rs '[.[] | select(.path == "/api/productions.json")][0].body.review_before_publishing' "$LOG")"
check "create uses preset + basename" "PRESET1 371_test" "$(jq -rs '[.[] | select(.path == "/api/productions.json")][0].body | "\(.preset) \(.output_basename)"' "$LOG")"
check "bearer auth sent" "bearer k" "$(jq -rs '[.[] | select(.path == "/api/productions.json")][0].auth' "$LOG")"
check "upload" "uploaded" "$(bash "$A" upload UUID1 video.mp4)"
bash "$A" upload UUID1 missing.mp4 2>/dev/null; check "upload missing file fails" "2" "$?"
check "start" "Audio Processing" "$(bash "$A" start UUID1)"
bash "$A" wait UUID1 0 >/dev/null; check "wait reports still running" "3" "$?"
check "wait until done" "done" "$(bash "$A" wait UUID1 30)"
bash "$A" transcript UUID1 transcript.txt >/dev/null
check "transcript downloaded" "Hallo und willkommen zur Folge." "$(cat transcript.txt)"
bash "$SCRIPTS/seo.sh" "YouTube Beschreibung" seo.md > desc.txt
check "metadata" "metadata updated" "$(bash "$A" metadata UUID1 "Marathon Training: Unser Plan" desc.txt "laufen, marathon , podcast")"
check "metadata tags trimmed" '["laufen","marathon","podcast"]' "$(jq -cs '[.[] | select(.path == "/api/production/UUID1.json" and .method == "POST")][0].body.metadata.tags' "$LOG")"
check "metadata summary keeps lines" "6" "$(jq -rs '[.[] | select(.path == "/api/production/UUID1.json" and .method == "POST")][0].body.metadata.summary' "$LOG" | wc -l | tr -d ' ')"
echo "png" > cover.png
check "cover" "cover uploaded" "$(bash "$A" cover UUID1 cover.png)"
bash "$A" cover UUID1 missing.png 2>/dev/null; check "cover missing file fails" "2" "$?"
check "no youtube url before publish" "" "$(bash "$A" youtube-url UUID1)"
bash "$A" publish UUID1 >/dev/null
check "youtube url after publish" "https://www.youtube.com/watch?v=abc123" "$(bash "$A" youtube-url UUID1)"
AUPHONIC_API_KEY=bad bash "$A" publish UUID1 >/dev/null 2>&1; check "http error fails" "nonzero" "$([ $? -ne 0 ] && echo nonzero || echo zero)"
( unset AUPHONIC_API_KEY; bash "$A" details UUID1 2>/dev/null ); check "missing credentials fail" "2" "$?"

echo
[ "$fails" -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
