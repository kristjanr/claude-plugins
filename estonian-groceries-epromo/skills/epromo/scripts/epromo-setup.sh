#!/usr/bin/env bash
set -euo pipefail

# Save ePromo credentials to config file
# Usage: epromo-setup.sh <token> <address> [cf_clearance]

CONFIG_DIR="${HOME}/.config/epromo"
CONFIG_FILE="${CONFIG_DIR}/credentials"

TOKEN="${1:?Usage: epromo-setup.sh <token> <address> [cf_clearance]}"
ADDRESS="${2:?Usage: epromo-setup.sh <token> <address> [cf_clearance]}"
CF_CLEARANCE="${3:-}"

mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_FILE" <<EOF
EPROMO_TOKEN=${TOKEN}
EPROMO_ADDRESS=${ADDRESS}
EPROMO_CF_CLEARANCE=${CF_CLEARANCE}
EOF
chmod 600 "$CONFIG_FILE"

echo "Credentials saved to ${CONFIG_FILE}"
