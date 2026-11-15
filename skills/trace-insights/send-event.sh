#!/usr/bin/env bash
# Fire-and-forget event sender for Trace. Always exits 0.
# Usage: send-event.sh --type agent.heartbeat [--task TRC-21] [--summary "..."] [--reason "..."]
#        [--confidence 0.9] [--engineer name] [--repo org/name] [--external-id id]

[ -f "$HOME/.trace/disabled" ] && exit 0

KEY="${TRACE_API_KEY:-$(cat "$HOME/.trace/key" 2>/dev/null)}"
URL="${TRACE_URL:-$(cat "$HOME/.trace/url" 2>/dev/null)}"
URL="${URL:-http://localhost:3000}"
[ -z "$KEY" ] && exit 0

TYPE="" TASK="" SUMMARY="" REASON="" CONF="" ENGINEER="" REPO="" EXT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --type) TYPE="$2"; shift 2 ;;
    --task) TASK="$2"; shift 2 ;;
    --summary) SUMMARY="$2"; shift 2 ;;
    --reason) REASON="$2"; shift 2 ;;
    --confidence) CONF="$2"; shift 2 ;;
    --engineer) ENGINEER="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --external-id) EXT="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[ -z "$TYPE" ] && exit 0

if [ -z "$REPO" ]; then
  REPO="$(git remote get-url origin 2>/dev/null | sed -E 's#\.git$##; s#.*[:/]([^/:]+/[^/]+)$#\1#')"
fi
[ -z "$ENGINEER" ] && ENGINEER="$(git config user.name 2>/dev/null)"

esc() { printf %s "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk 'BEGIN{ORS="\\n"} {print}' | sed 's/\\n$//'; }

BODY="{\"type\":\"$(esc "$TYPE")\""
[ -n "$TASK" ] && BODY="$BODY,\"task\":\"$(esc "$TASK")\""
[ -n "$SUMMARY" ] && BODY="$BODY,\"summary\":\"$(esc "${SUMMARY:0:280}")\""
[ -n "$REASON" ] && BODY="$BODY,\"reason\":\"$(esc "${REASON:0:2000}")\""
[ -n "$ENGINEER" ] && BODY="$BODY,\"engineer\":\"$(esc "$ENGINEER")\""
[ -n "$REPO" ] && BODY="$BODY,\"repo\":\"$(esc "$REPO")\""
[ -n "$EXT" ] && BODY="$BODY,\"externalId\":\"$(esc "$EXT")\""
case "$CONF" in ''|*[!0-9.]*) ;; *) BODY="$BODY,\"confidence\":$CONF" ;; esac
BODY="$BODY}"

curl -sS --max-time 5 -X POST "$URL/api/events" \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d "$BODY" >/dev/null 2>&1 || true
exit 0
