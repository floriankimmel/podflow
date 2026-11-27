#!/bin/bash
# Deploy the podflow backend to the Pi "withalm" (systemd unit `podflow`,
# public via Cloudflare Tunnel). Built on the Pi; WORKSPACE_KEY lives in
# /etc/apps/podflow.env on the Pi.
set -euo pipefail

PI_HOST="${PI_HOST:-withalm}"
APP=podflow
URL="https://podflow.withalm-pi.cc"
cd "$(dirname "$0")"

echo "📤 Syncing backend to $PI_HOST..."
rsync -az --delete --exclude '*.db*' --exclude 'Dockerfile' --exclude 'fly.toml' ./ "$PI_HOST:/srv/apps/src/$APP/"

echo "🏗️  Building on $PI_HOST and restarting..."
ssh "$PI_HOST" "bash -s" <<EOF
set -euo pipefail
export PATH=/usr/local/go/bin:\$PATH
cd /srv/apps/src/$APP
CGO_ENABLED=0 go build -trimpath -o /tmp/$APP.new .
sudo install -m755 /tmp/$APP.new /srv/apps/$APP/bin/$APP && rm /tmp/$APP.new
sudo systemctl restart $APP
sleep 2
systemctl is-active $APP
EOF

code=$(curl -s -o /dev/null -w '%{http_code}' "$URL/health")
[ "$code" = 200 ] || { echo "❌ Health check failed: $URL/health -> $code"; exit 1; }
echo "✅ Deployed: $URL"
