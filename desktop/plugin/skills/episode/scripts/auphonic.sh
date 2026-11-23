#!/bin/bash
# Auphonic API calls for the episode flow. bash + curl + jq only.
#
#   auphonic.sh create <title> <output-basename>   create production from preset, held for review; prints uuid
#   auphonic.sh upload <uuid> <file>               upload the input video
#   auphonic.sh start <uuid>                       start processing
#   auphonic.sh wait <uuid> [max-seconds]          poll until done; exit 0 done, 3 still running, 1 error
#   auphonic.sh transcript <uuid> <out-file>       download the speech-recognition transcript (txt)
#   auphonic.sh metadata <uuid> <title> <summary-file> <tags-csv>
#   auphonic.sh cover <uuid> <image-file>           set the cover (artwork of audio files and YouTube video)
#   auphonic.sh publish <uuid>                     release the held production to its outgoing services
#   auphonic.sh youtube-url <uuid>                 print the YouTube URL once released (empty if unknown)
#   auphonic.sh details <uuid>                     print production JSON
#
# Env: AUPHONIC_API_KEY (bearer) or AUPHONIC_USER + AUPHONIC_PWD (basic),
#      AUPHONIC_PRESET (preset uuid), AUPHONIC_BASE (default https://auphonic.com).
#
# The preset must carry the outgoing services (YouTube, audio server) and, for
# interview compilations, speech recognition with a transcript (txt) output file.
set -euo pipefail

BASE="${AUPHONIC_BASE:-https://auphonic.com}"

auth() {
  if [ -n "${AUPHONIC_API_KEY:-}" ]; then
    AUTH=(-H "Authorization: bearer ${AUPHONIC_API_KEY}")
  elif [ -n "${AUPHONIC_USER:-}" ] && [ -n "${AUPHONIC_PWD:-}" ]; then
    AUTH=(-u "${AUPHONIC_USER}:${AUPHONIC_PWD}")
  else
    echo "auphonic: set AUPHONIC_API_KEY or AUPHONIC_USER/AUPHONIC_PWD" >&2
    exit 2
  fi
}

# api <method> <path> [curl args...] -> response body; fails on HTTP >= 400.
api() {
  local method="$1" path="$2"
  shift 2
  local out code
  out="$(mktemp)"
  code="$(curl -sS -L -o "$out" -w '%{http_code}' -X "$method" "${AUTH[@]}" "$@" "${BASE}${path}")"
  if [ "$code" -ge 400 ]; then
    echo "auphonic: ${method} ${path} failed (HTTP ${code}): $(head -c 500 "$out")" >&2
    rm -f "$out"
    return 1
  fi
  cat "$out"
  rm -f "$out"
}

cmd="${1:-}"
[ -n "$cmd" ] || { sed -n '2,19p' "$0" >&2; exit 2; }
shift
auth

case "$cmd" in
  create)
    title="$1"; basename="$2"
    [ -n "${AUPHONIC_PRESET:-}" ] || { echo "auphonic: AUPHONIC_PRESET not set" >&2; exit 2; }
    body="$(jq -n --arg preset "$AUPHONIC_PRESET" --arg title "$title" --arg base "$basename" \
      '{preset: $preset, metadata: {title: $title}, output_basename: $base, review_before_publishing: true}')"
    api POST /api/productions.json -H "Content-Type: application/json" --data "$body" | jq -er '.data.uuid'
    ;;

  upload)
    uuid="$1"; file="$2"
    [ -f "$file" ] || { echo "auphonic: no such file: $file" >&2; exit 2; }
    api POST "/api/production/${uuid}/upload.json" --form "input_file=@${file}" | jq -er '.data.uuid' > /dev/null
    echo "uploaded"
    ;;

  start)
    api POST "/api/production/$1/start.json" | jq -er '.data.status_string'
    ;;

  wait)
    uuid="$1"; max="${2:-540}"; waited=0
    while :; do
      json="$(api GET "/api/production/${uuid}.json")"
      status="$(echo "$json" | jq -r '.data.status')"
      label="$(echo "$json" | jq -r '.data.status_string')"
      case "$status" in
        3) echo "done"; exit 0 ;;
        2|9|11) echo "auphonic: ${label}: $(echo "$json" | jq -r '.data.error_message // ""')" >&2; exit 1 ;;
      esac
      if [ "$waited" -ge "$max" ]; then
        echo "running: ${label}"
        exit 3
      fi
      sleep "${AUPHONIC_POLL_SECONDS:-20}"
      waited=$((waited + ${AUPHONIC_POLL_SECONDS:-20}))
    done
    ;;

  transcript)
    uuid="$1"; out="$2"
    url="$(api GET "/api/production/${uuid}.json" | jq -r '
      [.data.output_files[]? | select((.format == "transcript" or .format == "speech") and .ending == "txt")]
      | (.[0].download_url // empty)')"
    [ -n "$url" ] || { echo "auphonic: production has no txt transcript output (check preset: speech recognition + transcript txt)" >&2; exit 1; }
    code="$(curl -sS -L -o "$out" -w '%{http_code}' "${AUTH[@]}" "$url")"
    [ "$code" -lt 400 ] && [ -s "$out" ] || { echo "auphonic: transcript download failed (HTTP ${code})" >&2; exit 1; }
    echo "$out"
    ;;

  metadata)
    uuid="$1"; title="$2"; summary_file="$3"; tags="${4:-}"
    body="$(jq -n --arg title "$title" --rawfile summary "$summary_file" --arg tags "$tags" \
      '{metadata: {title: $title, summary: ($summary | sub("\\s+$"; "")),
                   tags: ($tags | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(. != "")))}}')"
    api POST "/api/production/${uuid}.json" -H "Content-Type: application/json" --data "$body" | jq -er '.data.uuid' > /dev/null
    echo "metadata updated"
    ;;

  cover)
    uuid="$1"; file="$2"
    [ -f "$file" ] || { echo "auphonic: no such file: $file" >&2; exit 2; }
    api POST "/api/production/${uuid}/upload.json" --form "image=@${file}" | jq -er '.data.uuid' > /dev/null
    echo "cover uploaded"
    ;;

  publish)
    api POST "/api/production/$1/publish.json" | jq -er '.data.status_string'
    ;;

  youtube-url)
    api GET "/api/production/$1.json" \
      | jq -r '[.data | .. | strings | select(test("^https?://(www\\.)?(youtube\\.com/watch|youtu\\.be/)"))] | (.[0] // empty)'
    ;;

  details)
    api GET "/api/production/$1.json"
    ;;

  *)
    echo "auphonic: unknown command: $cmd" >&2
    exit 2
    ;;
esac
