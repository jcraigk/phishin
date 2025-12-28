# MCP Tools

This folder contains Model Context Protocol (MCP) tools that enable AI assistants to query Phish performance data.

## Available Tools

| Tool | Purpose |
|------|---------|
| `list_years` | List available years |
| `list_tours` | List tours, optionally filtered by year |
| `list_shows` | List shows with various filters |
| `list_songs` | List all songs |
| `list_venues` | List venues |
| `get_song` | Get song details and performance history |
| `get_tour` | Get tour details |
| `get_venue` | Get venue details and show history |
| `get_playlist` | Get playlist details |
| `search` | Full-text search across shows, songs, venues, tours |
| `stats` | Statistical analysis of performances |

## Stats Tool - Analysis Types

The `stats` tool provides deep statistical analysis. Each analysis type answers different questions.

### gaps

Finds songs that haven't been played recently (bustout candidates).

**Example questions:**
- "What songs haven't been played in over 50 shows?"
- "Which commonly-played songs are overdue for a performance?"

**Key parameters:** `min_gap`, `limit`

---

### transitions

Analyzes what songs come before/after other songs.

**Example questions:**
- "What songs typically follow Tweezer?"
- "What are the most common song-to-song transitions in Phish history?"

**Key parameters:** `song_slug`, `direction` (before/after)

---

### set_positions

Analyzes where songs appear in setlists (openers, closers, encores).

**Example questions:**
- "What are the most common Set 1 openers?"
- "How often does Slave to the Traffic Light close a set?"

**Key parameters:** `position` (opener/closer/encore), `set`, `song_slug`

---

### predictions

Scores songs by likelihood of being played based on historical patterns.

**Example questions:**
- "What songs are most likely to be played at the next show?"
- "Which songs are statistically overdue based on their typical rotation?"

**Key parameters:** `limit`

---

### streaks

Tracks consecutive show appearances for songs.

**Example questions:**
- "What's the longest streak of consecutive shows with You Enjoy Myself?"
- "Which songs are currently on hot streaks?"

**Key parameters:** `song_slug`, `streak_type`

---

### geographic

Analyzes performances by location.

**Example questions:**
- "What states has Phish played the most shows in?"
- "What songs have never been played in Colorado?"

**Key parameters:** `geo_type` (state_frequency/never_played/state_debuts), `state`

---

### co_occurrence

Analyzes which songs appear together in the same show.

**Example questions:**
- "What songs most frequently appear in the same show as Reba?"
- "How often do Harry Hood and Slave to the Traffic Light appear together?"

**Key parameters:** `song_slug`, `song_b_slug`

---

### song_frequency

Counts how often songs are played within filters.

**Example questions:**
- "What were the most played songs in 2023?"
- "What songs has Phish played the most at MSG?"

**Key parameters:** `year`, `year_range`, `tour_slug`, `venue_slug`, `state`

