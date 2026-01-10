module Descriptions
  # IMPORTANT: When linking to tracks, always use the web 'url' field (e.g., https://phish.in/1997-11-22/tweezer),
  # NOT the 'mp3_url' blob field. The web URL provides a better user experience with context, artwork, and navigation.

  BASE = {
    list_tags: "List all tags with show and track counts. " \
               "Tags categorize content: Jamcharts (notable jams), Costume, Guest, Debut, and more. " \
               "follow-up: Use get_tag with a tag slug to see tagged items.",

    get_tag: "Get shows or tracks associated with a specific tag. " \
             "params: type='show' for tagged shows (e.g., costume); type='track' for tagged tracks (e.g., jamcharts). " \
             "display: Link dates to show URLs, song names to track web URLs (use 'url', not 'mp3_url'). Format dates as 'Jul 4, 2023'. " \
             "Example: | [Tweezer](track_url) | [Jul 4, 2023](show_url) |",

    list_playlists: "List user-created playlists with optional sorting. " \
                    "follow-up: Use get_playlist with slug for full track listing. " \
                    "display: Link playlist names to their URLs. Example: [My Favorite Jams](url)",

    get_playlist: "Get a playlist with track listing, show dates, and durations. " \
                  "display: Link playlist name to playlist URL, track titles to track web URLs (use 'url', not 'mp3_url'). " \
                  "Format dates as 'Jul 4, 2023'. Show max 10 tracks. " \
                  "Example: | [Tweezer](track_url) | [Jul 4, 2023](show_url) |",

    get_audio_track: "Get a song performance with audio URL. " \
                     "triggers: 'play [song]', 'random track', 'listen to', 'surprise me', " \
                     "or when user selects a performance from get_song results. " \
                     "params: random=true for random; slug='YYYY-MM-DD/track-slug' for specific. " \
                     "display: Link to track web URL (use 'url', not 'mp3_url'). The web page provides artwork, context, and navigation.",

    get_show: "Get a Phish show with full setlist, venue, tags, and gaps. " \
              "triggers: 'random show', specific dates ('Halloween 1995', '12/31/99'), " \
              "or follow-up to list_shows/search. " \
              "params: random=true for random; date='YYYY-MM-DD' for specific. " \
              "display: Format dates as 'Jul 4, 2023'. Link tracks to web URLs (use 'url', not 'mp3_url').",

    get_song: "Get a Phish song with performance history. " \
              "triggers: 'random song' or specific song by slug. " \
              "params: random=true for random; slug='song-slug' for specific. " \
              "display: Format dates as 'Jul 4, 2023'. Link tracks to web URLs (use 'url', not 'mp3_url').",

    get_tour: "Get a Phish tour with date range and show count. " \
              "params: random=true for random; slug='tour-slug' for specific. " \
              "follow-up: Use list_shows with tour_slug to get shows on this tour. " \
              "display: Format dates as 'Jul 4, 2023'.",

    get_venue: "Get a venue with location, show count, and date range. " \
               "params: random=true for random; slug='venue-slug' for specific. " \
               "follow-up: Use list_shows with venue_slug to get shows at this venue. " \
               "display: Format dates as 'Jul 4, 2023'.",

    list_shows: "Browse shows by year, date range, tour, or venue. Returns shows WITHOUT setlists. " \
                "params: At least one filter required. " \
                "follow-up: Call get_show with date to get full setlist and audio. " \
                "display: Link dates to show URLs, venues to venue URLs. Format dates as 'Jul 4, 2023'. " \
                "Example: | [Jul 4, 2023](show_url) | [MSG](venue_url) |",

    list_songs: "List Phish songs with optional filtering and sorting. " \
                "follow-up: Use get_song with slug for detailed performance history. " \
                "display: Link song titles to their URLs. Example: [Tweezer](url)",

    list_tours: "List all Phish tours with optional year filtering. " \
                "follow-up: Use get_tour with slug for tour details.",

    list_venues: "List Phish venues with optional geographic filtering. " \
                 "follow-up: Use get_venue with slug for venue details. " \
                 "display: Link venue names to their URLs. Example: [Madison Square Garden](url)",

    list_years: "List all years/eras when Phish performed, with show counts. " \
                "Eras: 1.0 (1983-2000), 2.0 (2002-2004), 3.0 (2009-2020), 4.0 (2021+). " \
                "follow-up: Use list_shows with year to see shows. " \
                "display: Link years to their URLs. Example: [1995](url)",

    search: "Case-insensitive substring search across shows, songs, venues, tours, tags, and playlists. " \
            "note: For specific dates ('Halloween 95', 'NYE 99'), use get_show directly. " \
            "follow-up: Call get_show for full setlist and audio details. " \
            "display: Link dates to show URLs, titles to song URLs, names to venue URLs. " \
            "Format dates as 'Jul 4, 2023'. " \
            "api: https://phish.in/api/v2/swagger_doc (no key required)",

    stats: "Statistical analysis: gaps (bustouts), transitions, set positions, " \
           "geographic patterns, co-occurrence, and song frequency. " \
           "display: Link song names to song URLs, dates to track web URLs (use 'url', not 'mp3_url'). Format dates as 'Jul 4, 2023'. " \
           "Example: | [Tweezer](song_url) | 42 | [Dec 31, 1995](track_url) | " \
           "api: https://phish.in/api/v2/swagger_doc (no key required)"
  }.freeze

  OPENAI_OVERRIDES = {
    get_audio_track: "Get a song performance with audio player widget. " \
                     "triggers: 'play [song]', 'random track', 'listen to', 'surprise me', " \
                     "or when user selects a performance from get_song results. " \
                     "params: random=true for random; slug='YYYY-MM-DD/track-slug' for specific. " \
                     "display: Widget renders audio player; provide only a brief 1-2 sentence summary. " \
                     "Link to track web URL (use 'url', not 'mp3_url').",

    get_show: "Get a Phish show with setlist widget. " \
              "triggers: 'random show', specific dates ('Halloween 1995', '12/31/99'), " \
              "or follow-up to list_shows/search. " \
              "params: random=true for random; date='YYYY-MM-DD' for specific. " \
              "display: Widget renders setlist; provide only a brief 1-2 sentence summary. Do NOT list tracks. " \
              "Link tracks to web URLs (use 'url', not 'mp3_url').",

    get_playlist: "Get a playlist with interactive widget. " \
                  "display: Widget renders track listing; provide only a brief 1-2 sentence summary. " \
                  "Do NOT list tracks. Link tracks to web URLs (use 'url', not 'mp3_url').",

    list_shows: "Browse shows by year, date range, tour, or venue. Returns shows WITHOUT setlists. " \
                "params: At least one filter required. " \
                "follow-up: Call get_show with date to display setlist widget. " \
                "display: Link dates to show URLs, venues to venue URLs. Format dates as 'Jul 4, 2023'. " \
                "Example: | [Jul 4, 2023](show_url) | [MSG](venue_url) |",

    search: "Case-insensitive substring search across shows, songs, venues, tours, tags, and playlists. " \
            "note: For specific dates ('Halloween 95', 'NYE 99'), use get_show directly. " \
            "follow-up: Call get_show to display setlist widget. " \
            "display: Link dates to show URLs, titles to song URLs, names to venue URLs. " \
            "Format dates as 'Jul 4, 2023'."
  }.freeze

  CLIENT_OVERRIDES = {
    openai: OPENAI_OVERRIDES,
    default: {}
  }.freeze

  def self.for(tool_name, client)
    client_sym = client.to_sym
    tool_sym = tool_name.to_sym

    overrides = CLIENT_OVERRIDES[client_sym] || {}
    overrides[tool_sym] || BASE[tool_sym]
  end
end
