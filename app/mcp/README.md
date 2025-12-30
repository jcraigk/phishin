# Phish.in MCP Tools Demo Script

Use these exact prompts to demonstrate each tool. Copy/paste them verbatim for consistent results.

---

## 1. list_years
**Vague Prompt:**
What years of Phish shows are available in the archive?

**Explicit Prompt:**
Call the `list_years` tool to show all available years of Phish performances.

---

## 2. list_tours
**Vague Prompt:**
What tours did Phish do in 1997?

**Explicit Prompt:**
Call the `list_tours` tool with year set to 1997 to show all tours from that year.

---

## 3. list_shows
**Vague Prompt:**
What were the top ten most popular shows played in 1997?

**Explicit Prompt:**
Call the `list_shows` tool with year set to 1997, sort_by set to "likes", sort_order set to "desc", and limit set to 10.

---

## 4. list_songs
**Vague Prompt:**
What are the top ten most played original Phish songs?

**Explicit Prompt:**
Call the `list_songs` tool with sort_by set to "times_played", sort_order set to "desc", song_type set to "original", and limit set to 10.

---

## 5. list_venues
**Vague Prompt:**
What New York venues has Phish played the most?

**Explicit Prompt:**
Call the `list_venues` tool with state set to "NY", sort_by set to "shows_count", sort_order set to "desc", and limit set to 10.

---

## 6. list_playlists
**Vague Prompt:**
What are the most liked user playlists?

**Explicit Prompt:**
Call the `list_playlists` tool with sort_by set to "likes_count", sort_order set to "desc", and limit set to 10.

---

## 7. list_tags
**Vague Prompt:**
What tags are available to categorize shows and tracks?

**Explicit Prompt:**
Call the `list_tags` tool to show all available tags with their show and track counts.

---

## 8. get_show (specific date)
**Vague Prompt:**
Show me the setlist from Nov 22, 1997.

**Explicit Prompt:**
Call the `get_show` tool with date set to "1997-11-22" to show the famous Denver show.

---

## 9. get_show (random)
**Vague Prompt:**
Surprise me with a random Phish show.

**Explicit Prompt:**
Call the `get_show` tool with random set to true.

---

## 10. get_song (specific)
**Vague Prompt:**
What are the longest Tweezer performances ever?

**Explicit Prompt:**
Call the `get_song` tool with slug set to "tweezer", sort_by set to "duration", sort_order set to "desc", and limit set to 10.

---

## 11. get_song (random)
**Vague Prompt:**
Tell me about a random Phish song.

**Explicit Prompt:**
Call the `get_song` tool with random set to true.

---

## 12. get_audio_track (specific)
**Vague Prompt:**
Play me the famous Tweezer from Nov 22, 1997

**Explicit Prompt:**
Call the `get_audio_track` tool with slug set to "1997-11-22/tweezer" to play the famous Tweezer.

---

## 13. get_audio_track (random)
**Vague Prompt:**
Play me a random Phish track.

**Explicit Prompt:**
Call the `get_audio_track` tool with random set to true.

---

## 13b. get_audio_track (no audio available)
**Explicit Prompt:**
Call the `get_audio_track` tool with slug set to "1987-10-10/prep-school-hippie" to test the missing audio state.

---

## 14. get_tour
**Vague Prompt:**
Tell me about Fall Tour 1997.

**Explicit Prompt:**
Call the `get_tour` tool with slug set to "fall-tour-1997".

---

## 15. get_venue
**Vague Prompt:**
Tell me about Phish at Madison Square Garden.

**Explicit Prompt:**
Call the `get_venue` tool with slug set to "madison-square-garden".

---

## 16. get_tag (tracks by likes)
**Vague Prompt:**
What are the most liked tracks marked with the jamcharts tag?

**Explicit Prompt:**
Call the `get_tag` tool with slug set to "jamcharts", type set to "track", sort_by set to "likes", sort_order set to "desc", and limit set to 10.

---

## 17. get_tag (shows random)
**Vague Prompt:**
Show me a random show marked with the costume tag.

**Explicit Prompt:**
Call the `get_tag` tool with slug set to "costume", type set to "show", sort_by set to "random", and limit set to 1.

---

## 18. get_tag (tracks by duration)
**Vague Prompt:**
What are the longest performances marked with a jamcharts tag?

**Explicit Prompt:**
Call the `get_tag` tool with slug set to "jamcharts", type set to "track", sort_by set to "duration", sort_order set to "desc", and limit set to 10.

---

## 19. get_playlist (random)
**Vague Prompt:**
Show me a random user playlist.

**Explicit Prompt:**
Call the `get_playlist` tool with no parameters to get a random playlist.

---

## 20. search
**Vague Prompt:**
Search for anything related to Red.

**Explicit Prompt:**
Call the `search` tool with query set to "red" and limit set to 5.

---

## 21. stats - gaps (bustout candidates)
**Vague Prompt:**
What commonly-played songs haven't been performed in over 100 shows?

**Explicit Prompt:**
Call the `stats` tool with stat_type set to "gaps", min_gap set to 100, min_plays set to 10, and limit set to 10.

---

## 22. stats - transitions
**Vague Prompt:**
What songs typically follow Tweezer?

**Explicit Prompt:**
Call the `stats` tool with stat_type set to "transitions", song_slug set to "tweezer", direction set to "after", and limit set to 10.

---

## 23. stats - set_positions (openers)
**Vague Prompt:**
What are the most common Set 2 openers?

**Explicit Prompt:**
Call the `stats` tool with stat_type set to "set_positions", position set to "opener", set set to "2", and limit set to 10.

---

## 24. stats - set_positions (closers)
**Vague Prompt:**
What songs close Set 2 most often?

**Explicit Prompt:**
Call the `stats` tool with stat_type set to "set_positions", position set to "closer", set set to "2", and limit set to 10.

---

## 25. stats - geographic (state frequency)
**Vague Prompt:**
What states has Phish played the most shows in?

**Explicit Prompt:**
Call the `stats` tool with stat_type set to "geographic", geo_type set to "state_frequency", and limit set to 10.

---

## 26. stats - geographic (never played in state)
**Vague Prompt:**
What popular songs has Phish never played in Colorado?

**Explicit Prompt:**
Call the `stats` tool with stat_type set to "geographic", geo_type set to "never_played", state set to "CO", min_plays set to 50, and limit set to 10.

---

## 27. stats - co_occurrence
**Vague Prompt:**
What songs frequently appear in the same show as You Enjoy Myself?

**Explicit Prompt:**
Call the `stats` tool with stat_type set to "co_occurrence", song_slug set to "you-enjoy-myself", and limit set to 10.

---

## 28. stats - song_frequency (by year)
**Vague Prompt:**
What were the most played songs in 2023?

**Explicit Prompt:**
Call the `stats` tool with stat_type set to "song_frequency", year set to 2023, and limit set to 10.

---

## 29. stats - song_frequency (at venue)
**Vague Prompt:**
What songs has Phish played the most at Madison Square Garden?

**Explicit Prompt:**
Call the `stats` tool with stat_type set to "song_frequency", venue_slug set to "madison-square-garden", and limit set to 10.

---

## Demo Flow Suggestion

For a cohesive video narrative, consider this order:

1. **Introduction**: `list_years` → Show the scope of the archive
2. **Browse by Year**: `list_tours` (1997) → `list_shows` (1997, by likes)
3. **Show Details**: `get_show` (1997-11-22) → Display the widget with setlist
4. **Play Audio**: `get_audio_track` (1997-11-22/tweezer) → Audio player widget
5. **Song Deep Dive**: `get_song` (tweezer, by duration) → Show performance history
6. **Discovery**: `get_show` (random) → Surprise the viewer
7. **Tags**: `list_tags` → `get_tag` (jamcharts, top liked tracks)
8. **Search**: `search` ("madison square garden")
9. **Venue Info**: `get_venue` (madison-square-garden)
10. **Analytics**: 
   - `stats` (set_positions, Set 2 openers)
   - `stats` (transitions, what follows Tweezer)
   - `stats` (gaps, bustout candidates)
11. **Playlists**: `list_playlists` → `get_playlist` (random)
