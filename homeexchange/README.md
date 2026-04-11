# HomeExchange Search Plugin

Search for free homes to stay in via [HomeExchange.com](https://www.homeexchange.com) using your logged-in browser session.

## Prerequisites

- Claude-in-Chrome browser extension
- A HomeExchange.com account (logged in via the browser)

## How it works

HomeExchange.com requires authentication for search. This plugin runs API calls directly inside a Chrome browser tab using your existing session — no credentials needed.

**Workflow:**
1. Open homeexchange.com in Chrome and log in
2. Ask Claude to search for homes
3. Claude interviews you about your destination, dates, guests, and preferences
4. Claude executes the search via your browser session
5. Results are displayed sorted by GuestPoints per night

## Install

```
/plugin marketplace add kristjanr/claude-plugins
/plugin install homeexchange
```

## Usage

Just ask Claude to search HomeExchange:

- "Find homes in Lisbon on HomeExchange for 2 weeks in July"
- "Search HomeExchange for a 2-bedroom place in Barcelona"
- "What home exchanges are available in Tokyo next spring?"
