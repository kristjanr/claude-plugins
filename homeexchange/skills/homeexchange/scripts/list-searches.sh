#!/usr/bin/env bash
set -euo pipefail

# List all saved HomeExchange searches.
# Usage: list-searches.sh

BASE="${HOME}/.homeexchange/searches"

if [ ! -d "$BASE" ]; then
  echo "No searches saved yet. Searches are stored in ${BASE} after each HomeExchange search."
  exit 0
fi

COUNT=0
while IFS= read -r query_file; do
  dir=$(dirname "$query_file")
  relative="${dir#"${BASE}/"}"
  # relative is Country/Location/search-folder
  IFS='/' read -r country location search_folder <<< "$relative"
  results_file="${dir}/results.json"
  total=""
  if [ -f "$results_file" ]; then
    total=$(python3 -c "import json; d=json.load(open('${results_file}')); print(d.get('total','?'))" 2>/dev/null || echo "?")
  fi
  printf "%-30s  %-25s  %-40s  %s homes\n" "$country" "$location" "$search_folder" "$total"
  COUNT=$((COUNT + 1))
done < <(find "$BASE" -name "query.json" | sort)

if [ "$COUNT" -eq 0 ]; then
  echo "No searches saved yet."
fi
