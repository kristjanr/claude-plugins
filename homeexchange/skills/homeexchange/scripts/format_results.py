#!/usr/bin/env python3
"""
Format HomeExchange search results from the BFF API response.

Usage:
  cat response.json | python3 format_results.py [--max-gp N] [--min-bedrooms N] [--min-rating N] [--limit N]
  python3 format_results.py response.json [--sort gp|rating|reviews]
"""

import json, sys, argparse

def format_home(h, rank):
    rating, reviews = h.get("rating"), h.get("reviews", 0)
    rating_str = f"⭐ {rating:.1f} ({reviews} reviews)" if rating is not None else "⭐ No reviews yet"
    reactivity = h.get("reactivity", 0)
    verified = " ✓ Verified" if h.get("isVerified") else ""
    avail = h.get("available")
    avail_str = f"\n   📅 Available: {avail.get('from')} → {avail.get('to')}" if avail else ""
    min_str = f" · min {h['minNights']} nights" if h.get("minNights") else ""
    city = h.get('city') or ''
    country = h.get('country', '')
    loc = f"{city}, {country}" if city else country
    return (f"{rank}. {h.get('title', 'Unnamed')}{verified}\n"
            f"   📍 {loc}\n"
            f"   🛏  {h.get('bedrooms','?')} bedrooms · {h.get('beds','?')} beds · up to {h.get('capacity','?')} guests\n"
            f"   {rating_str}{f' · {reactivity}% response rate' if reactivity else ''}\n"
            f"   💎 {h.get('gpPerNight','?')} GP/night{min_str}\n"
            f"   🏠 Host: {h.get('hostName','?')}{avail_str}\n"
            f"   🔗 {h.get('url','')}")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("file", nargs="?")
    parser.add_argument("--max-gp", type=int)
    parser.add_argument("--min-bedrooms", type=int)
    parser.add_argument("--min-rating", type=float)
    parser.add_argument("--min-capacity", type=int)
    parser.add_argument("--sort", choices=["gp", "rating", "reviews"], default="gp")
    parser.add_argument("--limit", type=int, default=20)
    args = parser.parse_args()

    data = json.load(open(args.file) if args.file else sys.stdin)
    raw_homes, total = data.get("homes", []), data.get("total", 0)

    homes = []
    for h in raw_homes:
        if "homeId" in h:
            t = h.get("translations") or {}
            homes.append({
                "id": h["homeId"],
                "title": t.get("title", {}).get("en") or t.get("title", {}).get("fr", "Unnamed"),
                "city": (t.get("location") or {}).get("city", {}).get("en"),
                "country": (t.get("location") or {}).get("country", {}).get("en"),
                "bedrooms": (h.get("beds") or {}).get("bedroomsCount"),
                "beds": (h.get("beds") or {}).get("bedsCount"),
                "capacity": h.get("capacity"),
                "gpPerNight": h.get("gpPerNight"),
                "minNights": h.get("minimumOfNights"),
                "rating": (h.get("user") or {}).get("rating"),
                "reviews": (h.get("user") or {}).get("reviews", 0),
                "hostName": (h.get("user") or {}).get("firstName"),
                "reactivity": (h.get("user") or {}).get("reactivityLevel"),
                "isVerified": h.get("isVerified", False),
                "available": (h.get("searchContext") or {}).get("next_availability"),
                "url": f"https://www.homeexchange.com/homes/view/{h['homeId']}"
            })
        else:
            homes.append(h)

    if args.max_gp: homes = [h for h in homes if h.get("gpPerNight") is not None and h["gpPerNight"] <= args.max_gp]
    if args.min_bedrooms: homes = [h for h in homes if h.get("bedrooms") is not None and h["bedrooms"] >= args.min_bedrooms]
    if args.min_rating: homes = [h for h in homes if h.get("rating") is not None and h["rating"] >= args.min_rating]
    if args.min_capacity: homes = [h for h in homes if h.get("capacity") is not None and h["capacity"] >= args.min_capacity]

    homes.sort(key=lambda h: h.get("gpPerNight") or 9999 if args.sort == "gp"
               else (-(h.get("rating") or 0), -(h.get("reviews") or 0)) if args.sort == "rating"
               else -(h.get("reviews") or 0))

    shown = homes[:args.limit]
    print(f"Found {total} homes total · {len(homes)} match filters · showing {len(shown)}\n")
    for i, h in enumerate(shown, 1):
        print(format_home(h, i))
        print()

if __name__ == "__main__":
    main()
