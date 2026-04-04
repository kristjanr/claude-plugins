#!/usr/bin/env bash
set -euo pipefail

TERM="${1:?Usage: epromo-search.sh <term> [count]}"
COUNT="${2:-6}"

# Load credentials from config file, env vars override
CONFIG_FILE="${HOME}/.config/epromo/credentials"
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
fi
export EPROMO_TOKEN="${EPROMO_TOKEN:-}"
export EPROMO_ADDRESS="${EPROMO_ADDRESS:-}"
export EPROMO_CF_CLEARANCE="${EPROMO_CF_CLEARANCE:-}"

# Fail loudly if credentials are missing
if [ -z "$EPROMO_TOKEN" ] || [ -z "$EPROMO_ADDRESS" ]; then
  echo '{"error": "Credentials not configured. Run the setup steps in SKILL.md first: extract token and DeliveryAddress cookies from an authenticated epromo.ee browser session, then run epromo-setup.sh <token> <address>"}' >&2
  exit 1
fi

python3 -c "
import json, sys, os
from curl_cffi import requests

term = sys.argv[1]
count = sys.argv[2]
token = os.environ.get('EPROMO_TOKEN', '')
address = os.environ.get('EPROMO_ADDRESS', '')
cf_clearance = os.environ.get('EPROMO_CF_CLEARANCE', '')

headers = {
    'content-type': 'application/json',
    'languages': 'et',
}
cookies = {}

if token:
    headers['authorization'] = f'Bearer {token}'
    cookies['token'] = token
if address:
    headers['addressid'] = address
if cf_clearance:
    cookies['cf_clearance'] = cf_clearance

r = requests.post(
    'https://epromo.ee/api/proxy/search-products',
    json={'search': term, 'count': str(count), 'page': '1', 'filters': []},
    headers=headers,
    cookies=cookies,
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
    'inStockAmount': p.get('inStockAmount', '?'),
    'minAmount': p['minimumAmount'],
    'priceCoeff': p.get('priceCoefficient', ''),
    'storageType': p['storageType']
} for p in data.get('products', [])]

print(json.dumps(products, indent=2, ensure_ascii=False))
" "$TERM" "$COUNT"
