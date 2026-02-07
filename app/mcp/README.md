# Phish.in MCP Server

[Phish.in](https://phish.in) is a community archive of live Phish recordings. This MCP server provides read-only access to the full archive including shows, songs, setlists, venues, tours, tags, playlists, audio streaming, and statistical analysis spanning every era of the band (1983-present).

## Setup

### Server Configuration

| Field | Value |
|---|---|
| **Endpoint** | `https://phish.in/mcp` |
| **Transport** | Streamable HTTP (JSON-RPC 2.0) |
| **Authentication** | None required |
| **Session** | Stateless |

All tools are **read-only** and **non-destructive**.

### Client Configuration

To connect to the Phish.in MCP server, add the following to your MCP client configuration:

```json
{
  "mcpServers": {
    "phishin": {
      "url": "https://phish.in/mcp"
    }
  }
}
```

No API key or authentication is needed. The server accepts standard MCP JSON-RPC 2.0 requests over HTTP POST.

### Client-Specific Endpoints

| Client | Endpoint |
|---|---|
| Default | `https://phish.in/mcp` |
| OpenAI | `https://phish.in/mcp/openai` |
| Anthropic | `https://phish.in/mcp/anthropic` |

The OpenAI and Anthropic endpoints include enhanced tool descriptions and interactive widget support (audio player, show cards, playlist cards).

---

## Tools

### list_years

List all years/eras when Phish performed, with show counts. Eras: 1.0 (1983-2000), 2.0 (2002-2004), 3.0 (2009-2020), 4.0 (2021+).

*No parameters.*

---

### list_tours

List all Phish tours with optional year filtering.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `year` | integer | no | Filter tours by year (e.g., 1997) |

---

### list_shows

Browse shows by year, date range, tour, or venue. Returns shows without full setlists — use `get_show` for setlist detail.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `year` | integer | no | Filter by year (e.g., 1997) |
| `start_date` | string | no | Start date for range filter (YYYY-MM-DD) |
| `end_date` | string | no | End date for range filter (YYYY-MM-DD) |
| `tour_slug` | string | no | Filter by tour slug (e.g., `fall-tour-1997`) |
| `venue_slug` | string | no | Filter by venue slug (e.g., `madison-square-garden`) |
| `sort_by` | string | no | `date` (default), `likes`, `duration`, or `random` |
| `sort_order` | string | no | `asc` (default for date) or `desc` |
| `limit` | integer | no | Max shows to return (default: 50) |

At least one filter is required: `year`, `start_date`, `end_date`, `tour_slug`, or `venue_slug`.

---

### list_songs

List Phish songs with optional filtering and sorting.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `song_type` | string | no | `all` (default), `original`, or `cover` |
| `sort_by` | string | no | `name` (default) or `times_played` |
| `sort_order` | string | no | `asc` (default for name) or `desc` (default for times_played) |
| `min_plays` | integer | no | Minimum number of performances |
| `limit` | integer | no | Max songs to return (default: 50) |

---

### list_venues

List Phish venues with optional geographic filtering.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `city` | string | no | Filter by city name |
| `state` | string | no | Filter by state (e.g., `NY`, `California`) |
| `country` | string | no | Filter by country (e.g., `USA`, `Germany`) |
| `sort_by` | string | no | `name` (default) or `shows_count` |
| `sort_order` | string | no | `asc` (default for name) or `desc` (default for shows_count) |
| `limit` | integer | no | Max venues to return (default: 50) |

---

### list_playlists

List user-created playlists with optional sorting.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `sort_by` | string | no | `name`, `likes_count` (default), `tracks_count`, `duration`, `updated_at`, or `random` |
| `sort_order` | string | no | `asc` or `desc` (default) |
| `limit` | integer | no | Max playlists to return (default: 50) |

---

### list_tags

List all tags with show and track counts. Tags categorize content (e.g., Jamcharts, Costume, Guest, Debut).

*No parameters.*

---

### get_show

Get a Phish show with full setlist, venue, tags, and song gap information.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `date` | string | no | Show date (YYYY-MM-DD). Omit for random show. |
| `random` | boolean | no | Set to `true` for a random show (ignores date) |

---

### get_song

Get a Phish song with performance history.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `slug` | string | no | Song slug (e.g., `tweezer`, `you-enjoy-myself`). Omit for random. |
| `random` | boolean | no | Set to `true` for a random song (ignores slug) |
| `sort_by` | string | no | Sort performances by `date` (default), `likes`, `duration`, or `random` |
| `sort_order` | string | no | `asc` or `desc` (default) |
| `limit` | integer | no | Max performances to return (default: 25) |

---

### get_audio_track

Get a song performance with a streamable audio URL.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `slug` | string | no | Track slug: `YYYY-MM-DD/track-slug` (e.g., `1997-11-22/tweezer`). Omit for random. |
| `random` | boolean | no | Set to `true` for a random audio track |

---

### get_tour

Get a Phish tour with date range and show count.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `slug` | string | no | Tour slug (e.g., `fall-tour-1997`). Omit for random. |
| `random` | boolean | no | Set to `true` for a random tour (ignores slug) |

---

### get_venue

Get a venue with location, show count, and date range.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `slug` | string | no | Venue slug (e.g., `madison-square-garden`). Omit for random. |
| `random` | boolean | no | Set to `true` for a random venue (ignores slug) |

---

### get_tag

Get shows or tracks associated with a specific tag.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `slug` | string | **yes** | Tag slug (e.g., `jamcharts`, `costume`, `guest`) |
| `type` | string | **yes** | `show` for tagged shows, `track` for tagged tracks |
| `sort_by` | string | no | `date` (default), `likes`, `duration` (tracks only), or `random` |
| `sort_order` | string | no | `asc` or `desc` (default) |
| `limit` | integer | no | Max items to return (default: 25) |

---

### get_playlist

Get a playlist with track listing, show dates, and durations.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `slug` | string | no | Playlist slug. Omit for a random playlist. |

---

### search

Case-insensitive substring search across shows, songs, venues, tours, tags, and playlists.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `query` | string | **yes** | Search query (2-200 characters) |
| `limit` | integer | no | Max results per category (default: 25) |

---

### stats

Statistical analysis covering gaps (bustouts), transitions, set positions, geographic patterns, co-occurrence, and song frequency.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `stat_type` | string | **yes** | `gaps`, `transitions`, `set_positions`, `geographic`, `co_occurrence`, or `song_frequency` |
| `song_slug` | string | no | Song slug for song-specific analysis |
| `song_b_slug` | string | no | Second song slug for co-occurrence comparison |
| `venue_slug` | string | no | Venue slug for venue-specific analysis |
| `year` | integer | no | Filter to specific year |
| `year_range` | integer[] | no | Filter to year range `[start, end]` |
| `tour_slug` | string | no | Filter to specific tour |
| `state` | string | no | US state code for geographic analysis (e.g., `CO`) |
| `min_gap` | integer | no | Minimum show gap for bustout queries |
| `min_plays` | integer | no | Minimum times played to include (default: 2) |
| `position` | string | no | `opener`, `closer`, or `encore` |
| `set` | string | no | Set number: `1`, `2`, `3`, or `4` (default: 1 for openers, 2 for closers) |
| `direction` | string | no | Transition direction: `before` or `after` |
| `geo_type` | string | no | `state_frequency`, `never_played`, or `state_debuts` |
| `limit` | integer | no | Max results to return (default: 25) |

#### stat_type usage

- **gaps** — Find songs with long gaps since last performance (bustout candidates). Use `min_gap` and `min_plays` to filter.
- **transitions** — Find which songs commonly precede or follow a given song. Requires `song_slug` and `direction`.
- **set_positions** — Find the most common openers, closers, or encores for a given set. Requires `position`; optionally specify `set`.
- **geographic** — Analyze geographic patterns. Requires `geo_type`. Use `state` with `never_played` to find songs unplayed in a state.
- **co_occurrence** — Find songs that frequently appear in the same show as a given song. Requires `song_slug`.
- **song_frequency** — Find most-played songs filtered by `year`, `venue_slug`, or `tour_slug`.

---

## Troubleshooting

### Common Issues

| Problem | Cause | Solution |
|---|---|---|
| Connection refused | Server unreachable | Verify the endpoint URL is `https://phish.in/mcp` (HTTPS required) |
| Empty response for `list_shows` | Missing required filter | Provide at least one filter: `year`, `start_date`, `end_date`, `tour_slug`, or `venue_slug` |
| No audio URL in `get_audio_track` response | Recording not yet digitized | Not all known performances have audio available; try a different track |
| `search` returns error | Query too short or too long | Query must be between 2 and 200 characters |
| `get_tag` returns error | Missing required params | Both `slug` and `type` are required |
| Unexpected sort order | Default varies by tool | Check the tool's `sort_order` default — some default to `asc`, others to `desc` |
| Slug not found | Incorrect slug format | Use `search` or the corresponding `list_*` tool to find the correct slug |

### Slug Formats

Slugs are URL-friendly identifiers used across most tools. Common formats:

- **Songs**: lowercase hyphenated (e.g., `you-enjoy-myself`, `tweezer`)
- **Venues**: lowercase hyphenated (e.g., `madison-square-garden`)
- **Tours**: lowercase hyphenated with year (e.g., `fall-tour-1997`)
- **Tracks**: `YYYY-MM-DD/song-slug` (e.g., `1997-11-22/tweezer`)
- **Tags**: lowercase hyphenated (e.g., `jamcharts`, `costume`)

Use the `search` tool to look up slugs if you're unsure of the exact format.

### Getting Help

- Browse the archive at [phish.in](https://phish.in)
- Report issues at [github.com/jcraigk/phishin](https://github.com/jcraigk/phishin/issues)

---

## Example Prompts

The following prompts can be used to demonstrate each tool. Both natural language ("vague") and explicit invocation styles are provided.

---

### 1. list_years
**Vague Prompt:**
What years of Phish shows are available in the archive?

**Explicit Prompt:**
Call the `list_years` tool to show all available years of Phish performances.

---

### 2. list_tours
**Vague Prompt:**
What tours did Phish do in 1997?

**Explicit Prompt:**
Call the `list_tours` tool with year set to 1997 to show all tours from that year.

---

### 3. list_shows
**Vague Prompt:**
What were the top ten most popular shows played in 1997?

**Explicit Prompt:**
Call the `list_shows` tool with year set to 1997, sort_by set to "likes", sort_order set to "desc", and limit set to 10.

---

### 4. list_songs
**Vague Prompt:**
What are the top ten most played original Phish songs?

**Explicit Prompt:**
Call the `list_songs` tool with sort_by set to "times_played", sort_order set to "desc", song_type set to "original", and limit set to 10.

---

### 5. list_venues
**Vague Prompt:**
What New York venues has Phish played the most?

**Explicit Prompt:**
Call the `list_venues` tool with state set to "NY", sort_by set to "shows_count", sort_order set to "desc", and limit set to 10.

---

### 6. list_playlists
**Vague Prompt:**
What are the most liked user playlists?

**Explicit Prompt:**
Call the `list_playlists` tool with sort_by set to "likes_count", sort_order set to "desc", and limit set to 10.

---

### 7. list_tags
**Vague Prompt:**
What tags are available to categorize shows and tracks?

**Explicit Prompt:**
Call the `list_tags` tool to show all available tags with their show and track counts.

---

### 8. get_show (specific date)
**Vague Prompt:**
Show me the setlist from Nov 22, 1997.

**Explicit Prompt:**
Call the `get_show` tool with date set to "1997-11-22" to show the famous Denver show.

---

### 9. get_show (random)
**Vague Prompt:**
Surprise me with a random Phish show.

**Explicit Prompt:**
Call the `get_show` tool with random set to true.

---

### 10. get_song (specific)
**Vague Prompt:**
What are the longest Tweezer performances ever?

**Explicit Prompt:**
Call the `get_song` tool with slug set to "tweezer", sort_by set to "duration", sort_order set to "desc", and limit set to 10.

---

### 11. get_song (random)
**Vague Prompt:**
Tell me about a random Phish song.

**Explicit Prompt:**
Call the `get_song` tool with random set to true.

---

### 12. get_audio_track (specific)
**Vague Prompt:**
Play me the famous Tweezer from Nov 22, 1997

**Explicit Prompt:**
Call the `get_audio_track` tool with slug set to "1997-11-22/tweezer" to play the famous Tweezer.

---

### 13. get_audio_track (random)
**Vague Prompt:**
Play me a random Phish track.

**Explicit Prompt:**
Call the `get_audio_track` tool with random set to true.

---

### 13b. get_audio_track (no audio available)
**Explicit Prompt:**
Call the `get_audio_track` tool with slug set to "1987-10-10/prep-school-hippie" to test the missing audio state.

---

### 14. get_tour
**Vague Prompt:**
Tell me about Fall Tour 1997.

**Explicit Prompt:**
Call the `get_tour` tool with slug set to "fall-tour-1997".

---

### 15. get_venue
**Vague Prompt:**
Tell me about Phish at Madison Square Garden.

**Explicit Prompt:**
Call the `get_venue` tool with slug set to "madison-square-garden".

---

### 16. get_tag (tracks by likes)
**Vague Prompt:**
What are the most liked tracks marked with the jamcharts tag?

**Explicit Prompt:**
Call the `get_tag` tool with slug set to "jamcharts", type set to "track", sort_by set to "likes", sort_order set to "desc", and limit set to 10.

---

### 17. get_tag (shows random)
**Vague Prompt:**
Show me a random show marked with the costume tag.

**Explicit Prompt:**
Call the `get_tag` tool with slug set to "costume", type set to "show", sort_by set to "random", and limit set to 1.

---

### 18. get_tag (tracks by duration)
**Vague Prompt:**
What are the longest performances marked with a jamcharts tag?

**Explicit Prompt:**
Call the `get_tag` tool with slug set to "jamcharts", type set to "track", sort_by set to "duration", sort_order set to "desc", and limit set to 10.

---

### 19. get_playlist (random)
**Vague Prompt:**
Show me a random user playlist.

**Explicit Prompt:**
Call the `get_playlist` tool with no parameters to get a random playlist.

---

### 20. search
**Vague Prompt:**
Search for anything related to Red.

**Explicit Prompt:**
Call the `search` tool with query set to "red" and limit set to 5.

---

### 21. stats - gaps (bustout candidates)
**Vague Prompt:**
What commonly-played songs haven't been performed in over 100 shows?

**Explicit Prompt:**
Call the `stats` tool with stat_type set to "gaps", min_gap set to 100, min_plays set to 10, and limit set to 10.

---

### 22. stats - transitions
**Vague Prompt:**
What songs typically follow Tweezer?

**Explicit Prompt:**
Call the `stats` tool with stat_type set to "transitions", song_slug set to "tweezer", direction set to "after", and limit set to 10.

---

### 23. stats - set_positions (openers)
**Vague Prompt:**
What are the most common Set 2 openers?

**Explicit Prompt:**
Call the `stats` tool with stat_type set to "set_positions", position set to "opener", set set to "2", and limit set to 10.

---

### 24. stats - set_positions (closers)
**Vague Prompt:**
What songs close Set 2 most often?

**Explicit Prompt:**
Call the `stats` tool with stat_type set to "set_positions", position set to "closer", set set to "2", and limit set to 10.

---

### 25. stats - geographic (state frequency)
**Vague Prompt:**
What states has Phish played the most shows in?

**Explicit Prompt:**
Call the `stats` tool with stat_type set to "geographic", geo_type set to "state_frequency", and limit set to 10.

---

### 26. stats - geographic (never played in state)
**Vague Prompt:**
What popular songs has Phish never played in Colorado?

**Explicit Prompt:**
Call the `stats` tool with stat_type set to "geographic", geo_type set to "never_played", state set to "CO", min_plays set to 50, and limit set to 10.

---

### 27. stats - co_occurrence
**Vague Prompt:**
What songs frequently appear in the same show as You Enjoy Myself?

**Explicit Prompt:**
Call the `stats` tool with stat_type set to "co_occurrence", song_slug set to "you-enjoy-myself", and limit set to 10.

---

### 28. stats - song_frequency (by year)
**Vague Prompt:**
What were the most played songs in 2023?

**Explicit Prompt:**
Call the `stats` tool with stat_type set to "song_frequency", year set to 2023, and limit set to 10.

---

### 29. stats - song_frequency (at venue)
**Vague Prompt:**
What songs has Phish played the most at Madison Square Garden?

**Explicit Prompt:**
Call the `stats` tool with stat_type set to "song_frequency", venue_slug set to "madison-square-garden", and limit set to 10.

---

## Demo Flow Suggestion

For a cohesive video narrative, consider this order:

1. **Introduction**: `list_years` — Show the scope of the archive
2. **Browse by Year**: `list_tours` (1997) — `list_shows` (1997, by likes)
3. **Show Details**: `get_show` (1997-11-22) — Display the widget with setlist
4. **Play Audio**: `get_audio_track` (1997-11-22/tweezer) — Audio player widget
5. **Song Deep Dive**: `get_song` (tweezer, by duration) — Show performance history
6. **Discovery**: `get_show` (random) — Surprise the viewer
7. **Tags**: `list_tags` — `get_tag` (jamcharts, top liked tracks)
8. **Search**: `search` ("madison square garden")
9. **Venue Info**: `get_venue` (madison-square-garden)
10. **Analytics**:
    - `stats` (set_positions, Set 2 openers)
    - `stats` (transitions, what follows Tweezer)
    - `stats` (gaps, bustout candidates)
11. **Playlists**: `list_playlists` — `get_playlist` (random)
