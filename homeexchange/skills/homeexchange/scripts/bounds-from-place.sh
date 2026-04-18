#!/usr/bin/env bash
set -euo pipefail

# Compute a bounding box from a place name + radius in km.
# Usage: bounds-from-place.sh "Place Name" <radius_km>
# Returns JSON: { "ne": {"lat":…,"lon":…}, "sw": {"lat":…,"lon":…}, "label":"…", "country":"…", "center":{"lat":…,"lon":…} }

PLACE="${1:?Usage: bounds-from-place.sh <place> <radius_km>}"
RADIUS_KM="${2:?Usage: bounds-from-place.sh <place> <radius_km>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RESULT=$("$SCRIPT_DIR/jawg-search.sh" "$PLACE" 1)

if [ -z "$RESULT" ] || [ "$RESULT" = "[]" ]; then
  echo '{"error": "No location found for: '"$PLACE"'"}' >&2
  exit 1
fi

python3 -c "
import json, math, sys

result = json.loads(sys.argv[1])[0]
lat = result['lat']
lon = result['lon']
radius_km = float(sys.argv[2])

lat_delta = radius_km / 111.32
lon_delta = radius_km / (111.32 * math.cos(math.radians(lat)))

print(json.dumps({
    'ne': {'lat': round(lat + lat_delta, 6), 'lon': round(lon + lon_delta, 6)},
    'sw': {'lat': round(lat - lat_delta, 6), 'lon': round(lon - lon_delta, 6)},
    'label': result['label'],
    'country': result['country'],
    'center': {'lat': lat, 'lon': lon},
}, indent=2))
" "$RESULT" "$RADIUS_KM"
