---
name: epromo
description: Use when the user wants to shop for groceries at ePromo.ee, search for products, add items to their ePromo cart, or view their cart. Uses a hybrid approach — search via CLI (curl_cffi), cart operations via Chrome browser.
allowed-tools: Bash(*epromo-search.sh*), mcp__claude-in-chrome__javascript_tool, mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__computer
---

# ePromo.ee Grocery Shopping

Build an ePromo.ee grocery cart through conversation.

## Architecture

ePromo.ee is behind Cloudflare WAF. This plugin uses a **hybrid approach**:

- **Search**: via `epromo-search.sh` (uses `curl_cffi` with Chrome TLS impersonation — no browser needed)
- **Cart operations** (add, view, clear): via `javascript_tool` in a Chrome browser tab (Cloudflare blocks non-browser PUT/POST requests)

## Prerequisites

- `curl_cffi` Python package installed (`pip3 install curl_cffi`)
- For cart operations: an epromo.ee tab **open and logged in** in the Claude-in-Chrome browser
- If not logged in, navigate to `https://epromo.ee/auth/login` and help the user log in first

## Workflow

1. **Search** for products using `epromo-search.sh` (fast, no browser needed)
2. **Present results** — show name, price, product code, stock status, and unit; let the user confirm or refine
3. **Find the ePromo tab** using `tabs_context_mcp` — look for a tab with `epromo.ee` in the URL
4. **Add confirmed items** to cart via `javascript_tool` in the browser tab
5. **Show cart summary** so the user can review before checkout
6. When done, tell the user to open epromo.ee in their browser to complete checkout

Always confirm product choices with the user before adding to cart. If a search returns multiple close matches, ask which one they want.

## Scripts

All scripts are in the `scripts/` directory relative to this file.

### epromo-search.sh

Search for products by keyword. Does NOT require authentication or browser.

```
epromo-search.sh <term> [count]
```

- `term` — search query (e.g. "piim", "juust", "kana filee")
- `count` — number of results, defaults to 6

Returns JSON array with: `id`, `name`, `price`, `unit`, `inStock`, `minAmount`, `priceCoeff`, `storageType`.

## Browser API Reference (Cart Operations)

Cart operations must be made via `mcp__claude-in-chrome__javascript_tool` in an epromo.ee tab.

### Add Items to Cart

```javascript
const token = document.cookie.match(/token=([^;]+)/)[1];
fetch('/api/proxy/quick-search?search=' + encodeURIComponent(TERM) + '&count=1&page=1')
  .then(r => r.json())
  .then(data => {
    const product = data.products[0];
    return fetch('/api/proxy/update-b2c-cart', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token },
      body: JSON.stringify({ cartItems: [{ amount: AMOUNT, product: product }] })
    });
  })
  .then(r => r.json())
```

- The `product` object from search must be passed **as-is** to the cart API — it needs the full object
- `amount` — quantity to add (respect `minimumAmount` from search results)
- **Requires `Authorization: Bearer <token>` header** — extract token from cookies
- Multiple items can be added at once by including multiple objects in `cartItems` array

### Add Multiple Items at Once

```javascript
const token = document.cookie.match(/token=([^;]+)/)[1];
// products = array of { product: <full product object from search>, amount: N }
fetch('/api/proxy/update-b2c-cart', {
  method: 'PUT',
  headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token },
  body: JSON.stringify({ cartItems: products })
}).then(r => r.json())
```

### View Cart

```javascript
const token = document.cookie.match(/token=([^;]+)/)[1];
fetch('/api/proxy/get-b2c-checkout-summary', {
  headers: { 'Authorization': 'Bearer ' + token }
})
  .then(r => r.json())
  .then(data => JSON.stringify(data, null, 2))
```

### Clear / Update Cart

To update quantities or remove items, send the full desired cart state:

```javascript
const token = document.cookie.match(/token=([^;]+)/)[1];
fetch('/api/proxy/update-b2c-cart', {
  method: 'PUT',
  headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token },
  body: JSON.stringify({ cartItems: [] })  // empty array clears the cart
}).then(r => r.json())
```

## Important Notes

- **Cloudflare WAF**: GET requests work via `curl_cffi` (Chrome TLS impersonation). PUT/POST requests MUST go through the browser.
- **Authentication**: The JWT token is stored in the `token` cookie, valid for ~365 days.
- **Language**: Product names may appear in English or Estonian depending on the product.
- **Stock**: Check `inStock` before adding. Out-of-stock items cannot be ordered.
- **Minimum amounts**: Some products have `minimumAmount > 1` (e.g. eggs sold in packs of 2+).
- **Storage types**: Products have `storageType` — "termo" (refrigerated), "frost" (frozen), "dry" (ambient).
- **Price**: Use `priceWithVat` for the displayed price. `priceCoefficient` shows the per-unit price (e.g. "0,96€/l").
