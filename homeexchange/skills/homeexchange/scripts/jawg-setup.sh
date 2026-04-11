#!/usr/bin/env bash
set -euo pipefail

# Save Jawg access token extracted from a HomeExchange autocomplete request URL.
# Usage: jawg-setup.sh <url>
#
# To get the URL: open HomeExchange in Chrome, open DevTools → Network tab,
# type something in the search box, right-click the autocomplete request
# (api.jawg.io/places/v1/autocomplete?...) → Copy → Copy URL, then paste it here.

URL="${1:?Usage: jawg-setup.sh <url>}"

# Extract access-token query param from the URL
TOKEN=$(echo "$URL" | grep -oE 'access-token=[^&]+' | cut -d= -f2)

if [ -z "$TOKEN" ]; then
  echo "Error: could not find 'access-token' in the provided URL." >&2
  echo "Make sure you copied the full URL from the autocomplete request." >&2
  exit 1
fi

CONFIG_DIR="${HOME}/.config/homeexchange"
CONFIG_FILE="${CONFIG_DIR}/credentials"
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_FILE" <<EOF
JAWG_TOKEN='${TOKEN}'
EOF
chmod 600 "$CONFIG_FILE"

echo "Token saved to ${CONFIG_FILE}"
