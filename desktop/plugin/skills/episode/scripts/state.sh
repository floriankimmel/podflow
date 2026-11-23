#!/bin/bash
# Episode step state in ./state.json, mirrored to the podflow backend.
#
#   state.sh get <step>                 print status (pending|in_progress|done|failed)
#   state.sh set <step> <status> [err]  set status (+ error text), report to backend
#   state.sh put <step> <key> <value>   store a data value for a step
#   state.sh data <step> <key>          print a stored data value
#   state.sh field <name>               print a top-level field (number, title, type, ...)
set -euo pipefail

STATE_FILE="${PODFLOW_STATE_FILE:-state.json}"
[ -f "$STATE_FILE" ] || echo '{"steps":{}}' > "$STATE_FILE"

update() {
  local tmp
  tmp="$(mktemp)"
  jq "$@" "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
}

report_backend() {
  local step="$1" status="$2"
  [ -n "${PODFLOW_BACKEND_URL:-}" ] && [ -n "${PODFLOW_WORKSPACE_KEY:-}" ] || return 0
  local number title payload
  number="$(jq -r '.number // empty' "$STATE_FILE")"
  [ -n "$number" ] || return 0
  title="$(jq -r '.title // empty' "$STATE_FILE")"
  payload="$(jq -n --arg step "$step" --arg status "$status" --arg number "$number" --arg title "$title" \
    '{step: $step, status: $status, metadata: {episodeNumber: $number, title: $title, profile: "video"}}')"
  # Best effort: backend problems never fail a step.
  curl -sS -m 10 -o /dev/null -X POST \
    -H "X-Workspace-Key: ${PODFLOW_WORKSPACE_KEY}" -H "Content-Type: application/json" \
    --data "$payload" "${PODFLOW_BACKEND_URL%/}/episodes/${number}/steps" 2>/dev/null || true
}

cmd="${1:-}"
case "$cmd" in
  get)
    jq -r --arg s "$2" '.steps[$s].status // "pending"' "$STATE_FILE"
    ;;
  set)
    step="$2"; status="$3"; err="${4:-}"
    case "$status" in pending|in_progress|done|failed) ;; *) echo "invalid status: $status" >&2; exit 2 ;; esac
    update --arg s "$step" --arg st "$status" --arg e "$err" --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '.steps[$s] = ((.steps[$s] // {}) + {status: $st, updatedAt: $t}
        | if $e == "" then del(.error) else .error = $e end)'
    report_backend "$step" "$status"
    ;;
  put)
    update --arg s "$2" --arg k "$3" --arg v "$4" '.steps[$s] = ((.steps[$s] // {}) | .data[$k] = $v)'
    ;;
  data)
    jq -r --arg s "$2" --arg k "$3" '.steps[$s].data[$k] // empty' "$STATE_FILE"
    ;;
  field)
    jq -r --arg k "$2" '.[$k] // empty' "$STATE_FILE"
    ;;
  *)
    echo "usage: state.sh get|set|put|data|field ..." >&2
    exit 2
    ;;
esac
