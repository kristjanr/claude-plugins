# ePromo.ee Grocery Shopping Plugin

Shop for groceries from [ePromo.ee](https://epromo.ee) via Claude Code.

## Prerequisites

- Claude-in-Chrome browser extension
- An epromo.ee account (logged in via the browser)

## How it works

Unlike traditional API-based plugins, ePromo.ee is protected by Cloudflare WAF which blocks all non-browser HTTP clients. This plugin runs `fetch()` calls directly inside a Chrome browser tab, bypassing Cloudflare entirely.

**Workflow:**
1. Open epromo.ee in Chrome and log in
2. Ask Claude to search for products or build a cart
3. Claude executes API calls via the browser tab (~200ms per call)
4. Review your cart on epromo.ee and complete checkout

## Install

```
/plugin marketplace add kristjanr/claude-plugins
/plugin install estonian-groceries-epromo
```

## Usage

Just ask Claude to shop at ePromo:

- "Otsi ePromost piima"
- "Lisa ostukorvi 2 pakki Alma piima"
- "Näita mu ePromo ostukorvi"
