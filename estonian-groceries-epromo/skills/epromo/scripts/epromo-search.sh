#!/usr/bin/env bash
set -euo pipefail

TERM="${1:?Usage: epromo-search.sh <term> [count]}"
COUNT="${2:-6}"

python3 -c "
import json, sys
from urllib.parse import quote
from curl_cffi import requests

term = quote(sys.argv[1])
count = sys.argv[2]

r = requests.get(
    f'https://epromo.ee/api/proxy/quick-search?search={term}&count={count}&page=1',
    impersonate='chrome116'
)

if r.status_code != 200:
    print(json.dumps({'error': f'HTTP {r.status_code}', 'body': r.text[:200]}))
    sys.exit(1)

data = r.json()
products = [{
    'id': p['id'],
    'name': p['name'],
    'price': p['priceWithVat'],
    'unit': p['measureUnit'],
    'inStock': p['inStock'],
    'minAmount': p['minimumAmount'],
    'priceCoeff': p['priceCoefficient'],
    'storageType': p['storageType']
} for p in data.get('products', [])]

print(json.dumps(products, indent=2, ensure_ascii=False))
" "$TERM" "$COUNT"
