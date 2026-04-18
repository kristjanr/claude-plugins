---
name: homeexchange
description: Search for available homes on HomeExchange.com using the user's logged-in browser session. Use this skill whenever the user wants to search for homes to stay in, find home exchange listings, or plan a home exchange trip. Trigger on requests like "find homes in X on HomeExchange", "search HomeExchange for X", "what exchanges are available in X", or "show me home exchanges in X".
---

# HomeExchange Search Skill

Searches HomeExchange.com for available homes using the user's existing browser session (no credentials needed — auth is handled automatically by the browser).

**Reference:** All valid filter values, types, and API field paths are in `references/filters.json`. Read it when constructing the API request or when explaining options to the user during the interview.

**Past searches:** If the user asks to see past searches or recall previous results, run `list-searches.sh` (from the working directory — it looks in `./searches`). To re-display a past result, run `format_results.py <path/to/results.json>` — it accepts `--sort gp|rating|reviews`, `--max-gp`, `--min-bedrooms`, `--min-rating`, `--limit` flags.

---

## Step 0: Interview the user

Ask these **core questions** in a single conversational message:

1. **Where** do you want to stay?
2. **When?** — arrival and departure dates
3. **Who's coming?** — number of adults and babies/small children (each need their own bed)
4. **How flexible** are you with the dates? (in days either side)
5. **Exchange type** — GuestPoints only, reciprocal home swap, or either?
6. **GuestPoints budget** — min and max GP/night?
7. **Min bedrooms?**
8. **Entire home only**, or is a private room OK?
9. **Any must-have amenities for children?** — e.g. baby bed, kids' toys, playground, baby gear, children-welcome

Then ask: *"That covers the essentials. Want to set any of these too, or should I search now?"*

**Optional extras** — only proceed if the user says yes:
- Min bathrooms?
- No loft/temporary beds?
- Surroundings: seaside, mountains, countryside, village, city, isolated, island, lakes?
- Other must-have amenities (WiFi, pool, AC, parking, dishwasher, etc.)?
- Verified hosts only? Responsive hosts only?
- Pet allergies — exclude homes with cats, dogs, or other animals?
- Eco-friendly homes only?
- Show only your favorited homes?

---

## Step 1: Build the API request

Assemble the body from the answers. Only include fields the user actually answered — omit anything they skipped or left blank.

```javascript
const body = {
  last_search: { place: "DESTINATION" },
  search_query: {

    // LOCATION — resolved via Jawg autocomplete (see Step 2)
    location: {
      polygon: {
        location_id: "openstreetmap:PLACE_TYPE:relation/OSM_ID",
        provider: "Jawg"
      }
    },

    // DATES & FLEXIBILITY
    calendar: {
      date_ranges: [{ from: "YYYY-MM-DD", to: "YYYY-MM-DD" }],
      flexibility: /* days, e.g. 7 or 30 */,
      exchange_types: [
        // "guest-wanted"  → GuestPoints only
        // "reciprocal"    → Home swap only
        // "available"     → Either
      ]
    },

    // GUESTPOINTS BUDGET — omit if user didn't specify
    guestpoints: { from: /* min */, to: /* max */ },

    home: {
      // GUEST COMPOSITION & SIZE
      size: {
        beds: { adults: /* n */, babies: /* n */ },
        bedrooms: /* min, if specified */,
        bathrooms: /* min, if specified */
      },

      // ENTIRE HOME vs PRIVATE ROOM
      is_private_room: false,   // true = private room OK; false = entire home only

      // AMENITIES — only include codes the user asked for
      amenities: [
        // Family:       "baby-bed", "kids-toys", "playground", "baby-gear", "secured-pool"
        // Accessibility:"children-welcome", "pets-welcome", "disabled-access", "smokers-welcome"
        // Remote work:  "dedicated-workspace", "high-speed-connexion"
        // Basics:       "wifi", "heating-system", "dishwasher", "washing-machine",
        //               "dryer", "bathtub", "electric-car-plug", "tv"
        // Premium:      "a-c", "elevator", "parking-space", "jacuzzi", "fireplace",
        //               "gym", "garden", "balcony-terrace", "bbq", "swimming-pool",
        //               "bicycle", "car", "cleaning-person"
        // Location:     "public-transit-access"
      ],

      // SURROUNDINGS — only if user specified
      surrounding: [
        // "seaside", "countryside", "mountains", "cities", "villages",
        // "isolated", "island", "lakes"
      ],

      // PET ALLERGIES — only if user specified
      exclude_animals: [
        // "cat", "dog", "other"
      ],

      // ECO-FRIENDLY — only if user wants it (level 1–4)
      // eco_level: 4
    },

    // QUALITY FLAGS — include only what user confirmed
    filters: [
      // "home-verified"                  → verified homes only
      // "response-rate-above-threshold"  → responsive hosts only
      // "no-bed-up"                      → no loft/temporary beds
    ],

    // SPECIAL SEARCHES — only if user asked
    // favorite: true,    // show only favorited homes
    // reverse: [homeId]  // homes from members who wishlisted your place
  }
};
```

---

## Step 2: Resolve the location

Use the `jawg-search.sh` script — it calls HomeExchange's own Jawg autocomplete and returns `location_id` values in exactly the format the search API expects.

```
jawg-search.sh "DESTINATION"
```

Example output:
```json
[
  { "id": "openstreetmap:locality:relation/7900565", "label": "Paphos, Cyprus", "layer": "locality", "country": "Cyprus" },
  { "id": "openstreetmap:macroregion:relation/3311303", "label": "Paphos District, Cyprus", "layer": "macroregion", "country": "Cyprus" }
]
```

**Picking the right result:**
- The `id` is used directly as `location_id` in the search body — both `openstreetmap:LAYER:relation/ID` and `whosonfirst:LAYER:ID` formats work as-is
- **If there is exactly 1 result, use it directly.**
- **If there are 2 or more results, always show them all to the user and ask which one to use — never auto-pick.** Format them as a numbered list with label and layer so the user can make an informed choice, e.g.:
  ```
  I found multiple matches for "Mallorca":
  1. Mallorca, Spain (island)
  2. Palma de Mallorca, Spain (locality)
  3. Mallorca County, Spain (county)
  Which should I use? Note: island/county covers more area; locality is just the city.
  ```

**Query tips** — what works and what doesn't:
- Do NOT append "island" to queries — it confuses the geocoder ("Malta island" → 0 results; "Malta" → works fine)
- Small resorts may not have their own result — use the nearest locality or district instead (e.g. Ayia Napa → try "Paralimni")
- Small islands (e.g. Gozo) may have no island-level result — fall back to locality or country
- For archipelagos, run separate searches per island — they behave independently in the API

**First-time setup** — if the script errors about a missing token, ask the user to:
1. Open HomeExchange in Chrome and type something in the destination search box
2. Open DevTools → Network tab, filter by "jawg"
3. Right-click the `autocomplete?...` request → Copy → Copy URL
4. Run: `jawg-setup.sh <url>`

---

## Step 3: Call the API from the browser

Run via `javascript_tool` in the logged-in Chrome tab (navigate to homeexchange.com first if needed).

**Important:** top-level `await` fails in `javascript_tool` — always wrap in an async IIFE. Declare `const body = {...}` before or inside the IIFE — do not split it across separate code blocks:

```javascript
(async () => {
  const body = { /* assembled in Step 1 */ };
  const resp = await fetch('https://bff.homeexchange.com/search/homes?offset=0&limit=20', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-SEARCH-API-VERSION': 'v2',
      'X-HE-PAGE-NAME': 'SEARCH_PAGE',
      'X-LEGACY-RESPONSE': 'false'
    },
    body: JSON.stringify(body)
  });
  const data = await resp.json();

  // Return clean mapped fields to avoid truncation
  return {
    total: data.total,
    homes: (data.homes || []).map(h => ({
      id: h.homeId,
      title: h.translations?.title?.en,
      city: h.translations?.location?.city?.en,
      country: h.translations?.location?.country?.en,
      bedrooms: h.beds?.bedroomsCount,
      beds: h.beds?.bedsCount,
      capacity: h.capacity,
      gpPerNight: h.gpPerNight,
      minNights: h.minimumOfNights,
      rating: h.user?.rating,
      reviews: h.user?.reviews,
      hostName: h.user?.firstName,
      reactivity: h.user?.reactivityLevel,
      isVerified: h.isVerified,
      available: h.searchContext?.next_availability,
      url: 'https://www.homeexchange.com/homes/view/' + h.homeId,
      description: h.translations?.description?.en?.substring(0, 500),
      hostDescription: h.translations?.hostDescription?.en?.substring(0, 300),
      amenities: h.amenities?.map(a => a.slug),
      surrounding: h.surrounding,
    }))
  };
})()
```

For more results, paginate: `offset=20`, `offset=40`, up to `offset=80`.

---

## Step 4: Display results

Sort by `gpPerNight` ascending (cheapest first) unless the user asked for a different sort.

```
Found {total} homes in {DESTINATION}
{dates} · ±{flexibility} days flexibility · {exchange type}

1. {title}{" ✓ Verified" if isVerified}
   📍 {city}, {country}
   🛏  {bedrooms} bedrooms · {beds} beds · up to {capacity} guests
   ⭐ {rating} ({reviews} reviews) · {reactivity}% response rate
   💎 {gpPerNight} GP/night · min {minNights} nights
   📅 Available: {available.from} → {available.to}
   🏠 Host: {hostName}
   📝 {description}        ← omit if null
   💬 {hostDescription}    ← omit if null
   🔗 [View listing]({url})
```

If a home has no reviews, show "No reviews yet". Omit `description` and `hostDescription` lines if null. If `amenities` or `surrounding` contain values relevant to the user's stated preferences (e.g. baby-bed, parking, seaside), call them out inline rather than listing everything.

---

## Step 5: Save the search

After displaying results, persist the search to disk using the Write tool.

**Folder path:**
```
{working-directory}/searches/{Country}/{Location}/{today}_{arrival}_{departure}_{adults}a[_{babies}b]
```

- **Working directory**: the current working directory (use `pwd` via Bash to confirm if needed)
- **Country**: `country` field from the Jawg result (e.g. `Cyprus`)
- **Location**: place name from the Jawg label before the first comma (e.g. `Paphos`)
- **Search folder**: `{YYYY-MM-DD today}_{arrival}_{departure}_{adults}a` + `_{babies}b` if babies > 0

Example: `{working-directory}/searches/Cyprus/Paphos/2026-04-11_2026-10-11_2026-11-14_2a_2b`

**Files to write:**

`query.json` — the `search_query` body used (pretty-printed JSON):
```json
{ ...the search_query object from Step 1... }
```

`results.json` — the API response (pretty-printed JSON):
```json
{ "total": 42, "homes": [ ...mapped homes array... ] }
```

Create the directory first:
```bash
mkdir -p {working-directory}/searches/{Country}/{Location}/{search-folder}
```

Then write both files with the Write tool. Confirm to the user where the search was saved.

---

## Error handling

- **401/403:** User not logged in → ask them to log in at homeexchange.com then retry
- **0 results:** Suggest relaxing flexibility, widening GP range, or removing amenity requirements
- **Tool blocks response:** Ensure you're returning the mapped fields only, not raw API response data
