#!/usr/bin/env bash
set -euo pipefail

# Search for a location using HomeExchange's Jawg autocomplete API.
# Returns location candidates with their location_id for use in the search API.
# Usage: jawg-search.sh <text> [size]

TEXT="${1:?Usage: jawg-search.sh <text> [size]}"
SIZE="${2:-5}"

CONFIG_FILE="${HOME}/.config/homeexchange/credentials"
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
fi
JAWG_TOKEN="${JAWG_TOKEN:-}"

if [ -z "$JAWG_TOKEN" ]; then
  echo '{"error": "Jawg token not configured. Run jawg-setup.sh first: open HomeExchange in Chrome, open DevTools → Network tab, type in the search box, right-click the autocomplete request (api.jawg.io) → Copy URL, then run: jawg-setup.sh <url>"}' >&2
  exit 1
fi

LAYERS="island,dependency,locality,borough,localadmin,county,macrocounty,region,macroregion,country"
ENCODED_TEXT=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$TEXT")

curl -sf \
  "https://api.jawg.io/places/v1/autocomplete?access-token=${JAWG_TOKEN}&layers=${LAYERS}&sources=wof,osm&size=${SIZE}&text=${ENCODED_TEXT}" \
  -H 'accept: */*' \
  -H 'accept-language: en' \
  -H 'origin: https://www.homeexchange.com' \
  -H 'referer: https://www.homeexchange.com/' \
  | python3 -c "
import json, sys

data = json.load(sys.stdin)
results = [
  {
    'id': f['properties']['id'],
    'label': f['properties']['label'],
    'layer': f['properties']['layer'],
    'country': f['properties'].get('country', ''),
    'lat': f['geometry']['coordinates'][1],
    'lon': f['geometry']['coordinates'][0],
  }
  for f in data.get('features', [])
]
print(json.dumps(results, indent=2, ensure_ascii=False))
"
