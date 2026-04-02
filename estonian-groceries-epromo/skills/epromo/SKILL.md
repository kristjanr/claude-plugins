---
name: epromo
description: Use when the user wants to shop for groceries at ePromo.ee, search for products, add items to their ePromo cart, or view their cart. Requires an epromo.ee tab open and logged in within the Claude-in-Chrome browser.
allowed-tools: mcp__claude-in-chrome__javascript_tool, mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__computer
---

# ePromo.ee Grocery Shopping

Build an ePromo.ee grocery cart through conversation using browser-based API calls.

## Prerequisites

- The user must have an epromo.ee tab **open and logged in** in the Claude-in-Chrome browser
- If not logged in, navigate to `https://epromo.ee/auth/login` and help the user log in first
- All API calls run as `fetch()` inside the browser tab (required to bypass Cloudflare WAF)

## Workflow

1. **Find the ePromo tab** using `tabs_context_mcp` — look for a tab with `epromo.ee` in the URL
2. **Search** for products the user wants using the search API
3. **Present results** — show name, price, product code, stock status, and unit; let the user confirm or refine
4. **Add confirmed items** to cart using the cart API
5. **Show cart summary** so the user can review before checkout
6. When done, tell the user to open epromo.ee in their browser to complete checkout

Always confirm product choices with the user before adding to cart. If a search returns multiple close matches, ask which one they want.

## API Reference

All API calls must be made via `mcp__claude-in-chrome__javascript_tool` in an epromo.ee tab. The token for authenticated calls is extracted from cookies.

### Search Products

```javascript
fetch('/api/proxy/quick-search?search=' + encodeURIComponent(TERM) + '&count=' + COUNT + '&page=1')
  .then(r => r.json())
  .then(data => JSON.stringify(data.products.map(p => ({
    id: p.id, name: p.name, price: p.priceWithVat,
    unit: p.measureUnit, inStock: p.inStock,
    minAmount: p.minimumAmount, priceCoeff: p.priceCoefficient,
    storageType: p.storageType
  })), null, 2))
```

- `TERM` — search query (e.g. "piim", "juust", "kana")
- `COUNT` — number of results, default 6
- Returns: `products` array, plus `resultsCount`, `pageCount`, `categories`, `filters`
- Does NOT require authentication

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

- **Cloudflare WAF**: All API calls MUST go through the browser. curl/Node.js/fetch from CLI will be blocked.
- **Authentication**: The JWT token is stored in the `token` cookie, valid for ~365 days.
- **Language**: Product names may appear in English or Estonian depending on the product.
- **Stock**: Check `inStock` before adding. Out-of-stock items cannot be ordered.
- **Minimum amounts**: Some products have `minimumAmount > 1` (e.g. eggs sold in packs of 2+).
- **Storage types**: Products have `storageType` — "termo" (refrigerated), "frost" (frozen), "dry" (ambient).
- **Price**: Use `priceWithVat` for the displayed price. `priceCoefficient` shows the per-unit price (e.g. "0,96€/l").
