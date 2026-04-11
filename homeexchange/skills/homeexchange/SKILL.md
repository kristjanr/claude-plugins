---
name: homeexchange
description: Search for available homes on HomeExchange.com using the user's logged-in browser session. Use this skill whenever the user wants to search for homes to stay in, find home exchange listings, or plan a home exchange trip. Trigger on requests like "find homes in X on HomeExchange", "search HomeExchange for X", "what exchanges are available in X", or "show me home exchanges in X".
---

# HomeExchange Search Skill

Searches HomeExchange.com for available homes using the user's existing browser session (no credentials needed — auth is handled automatically by the browser).

**Reference:** All valid filter values, types, and API field paths are in `references/filters.json`. Read it when constructing the API request or when explaining options to the user during the interview.

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

    // LOCATION — resolved via Nominatim (see Step 2)
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
        // Family:       "baby-bed", "kids-toys", "playground", "baby-gear"
        // Accessibility:"children-welcome", "pets-welcome", "disabled-access", "smokers-welcome"
        // Remote work:  "dedicated-workspace", "high-speed-connexion"
        // Basics:       "wifi", "heating-system", "dishwasher", "washing-machine",
        //               "dryer", "bathtub", "electric-car-plug", "tv"
        // Premium:      "a-c", "elevator", "parking-space", "jacuzzi", "fireplace",
        //               "gym", "garden", "balcony-terrace", "bbq", "swimming-pool",
        //               "bicycle", "car", "cleaning-person", "secured-pool"
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
- Prefer `island` or `county` layer over `locality` for islands and archipelagos (e.g. Mallorca, Tenerife, Greek islands) — gives broader geographic coverage
- For countries that are the whole destination (Malta, Cyprus), `country` layer works fine
- If multiple plausible results are returned, show them to the user and ask which one they mean

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

**Important:** top-level `await` fails in `javascript_tool` — always wrap in an async IIFE:

```javascript
(async () => {
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
      url: 'https://www.homeexchange.com/homes/view/' + h.homeId
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
   🔗 [View listing]({url})
```

If a home has no reviews, show "No reviews yet".

---

## Error handling

- **401/403:** User not logged in → ask them to log in at homeexchange.com then retry
- **0 results:** Suggest relaxing flexibility, widening GP range, or removing amenity requirements
- **Tool blocks response:** Ensure you're returning the mapped fields only, not raw API response data
