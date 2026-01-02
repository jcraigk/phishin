module Descriptions
  BASE = {
    list_tags: "List all available tags with show and track counts. " \
               "Tags categorize content: Jamcharts (notable jams), Costume (costume shows), " \
               "Guest (guest musicians), Debut (song debuts), and more. " \
               "Use this to discover tag slugs before calling get_tag for tagged items.",

    get_tag: "Get shows or tracks associated with a specific tag. " \
             "Use type='show' for tagged shows (e.g., costume shows) or type='track' for tagged tracks (e.g., jamcharts). " \
             "Returns tag metadata plus list of associated shows or tracks with sorting options. " \
             "DISPLAY: In markdown, link dates to show/track urls. " \
             "Example: | [Tweezer](track_url) | [Jul 4, 2023](show_url) |. " \
             "Format dates readably (e.g., 'Jul 4, 2023').",

    list_playlists: "List user-created playlists with optional sorting. " \
                    "Returns playlist names, slugs, descriptions, durations, and track counts. " \
                    "Use this to discover playlists before calling get_playlist for full track listing. " \
                    "DISPLAY: In markdown, link playlist names to their url field. " \
                    "Example: [My Favorite Jams](url).",

    get_playlist: "Get detailed information about a user-created playlist. " \
                  "Returns playlist metadata and track listing with show dates and durations. " \
                  "DISPLAY: In markdown, link playlist name to playlist url and track titles to track url. " \
                  "Example: | [Tweezer](track_url) | [Jul 4, 2023](show_url) |. " \
                  "Format dates readably (e.g., 'Jul 4, 2023'). " \
                  "Display a maximum of 10 tracks in chat.",

    get_audio_track: "Play a song performance with audio player widget. Supports random. " \
                     "USE THIS when user wants to LISTEN to a specific performance or random track. " \
                     "WHEN TO USE: 'play [song]', 'random track', 'random performance', 'listen to', " \
                     "'surprise me', or when user selects a specific performance from get_song results. " \
                     "For random: call with random=true. " \
                     "For specific: use slug 'YYYY-MM-DD/track-slug' (e.g., '1997-11-22/tweezer').",

    get_show: "Get a Phish show with full setlist. Supports random. " \
              "WHEN TO USE: 'random show', specific dates ('Halloween 1995', '12/31/99'), " \
              "or follow-up to list_shows/search. " \
              "For random: call with random=true (no date needed). " \
              "Returns setlist with all tracks, venue, tags, and gaps. " \
              "Format dates readably (e.g., 'Jul 4, 2023').",

    get_song: "Get a Phish song with performance history. Supports random. " \
              "WHEN TO USE: 'random song' or specific song by slug. " \
              "For random: call with random=true (no slug needed). " \
              "Returns song metadata and list of performances. " \
              "Format dates readably (e.g., 'Jul 4, 2023').",

    get_tour: "Get a Phish tour. Supports random. " \
              "For random: call with random=true (no slug needed). " \
              "Returns tour metadata including date range and show count. " \
              "Use list_shows with tour_slug to get shows on this tour. " \
              "Format dates readably (e.g., 'Jul 4, 2023').",

    get_venue: "Get a venue. Supports random. " \
               "For random: call with random=true (no slug needed). " \
               "Returns venue metadata including location, show count, and date range. " \
               "Use list_shows with venue_slug to get shows at this venue. " \
               "Format dates readably (e.g., 'Jul 4, 2023').",

    list_shows: "Browse multiple shows by year, date range, tour, or venue. " \
                "Returns a list of shows WITHOUT setlists. " \
                "At least one filter is required. " \
                "FOLLOW-UP: If the result is a single show, or the user wants a random/specific show, " \
                "ALWAYS call get_show with that date to get full setlist and audio details. " \
                "DISPLAY: In markdown, link dates to show url and venues to venue url. " \
                "Example: | [Jul 4, 2023](show_url) | [MSG](venue_url) |. " \
                "Format dates readably (e.g., 'Jul 4, 2023').",

    list_songs: "List Phish songs with optional filtering and sorting. " \
                "Returns song names, slugs, play counts, and cover/original status. " \
                "Use this to discover songs before calling get_song for detailed performance history. " \
                "DISPLAY: In markdown, link song titles to their url field. " \
                "Example: [Tweezer](url).",

    list_tours: "List all Phish tours with optional year filtering. " \
                "Returns tour names, slugs, and date ranges. " \
                "Use this to discover available tours before calling get_tour.",

    list_venues: "List Phish venues with optional geographic filtering. " \
                 "Returns venue names, slugs, locations, and show counts. " \
                 "Use this to discover venue slugs before calling get_venue. " \
                 "DISPLAY: In markdown, link venue names to their url field. " \
                 "Example: [Madison Square Garden](url).",

    list_years: "List all years/periods when Phish performed, with show counts and era designations. " \
                "Eras: 1.0 (1983-2000), 2.0 (2002-2004), 3.0 (2009-2020), 4.0 (2021-present). " \
                "Note: Some fans consider all post-2.0 shows to be 3.0 (no distinction between 3.0/4.0). " \
                "Use this to discover available years before calling list_shows. " \
                "DISPLAY: In markdown, link years/periods to their url field. " \
                "Example: [1995](url) or [1983-1987](url).",

    search: "Simple case-insensitive substring search (not semantic) across Phish shows, songs, venues, tours, tags, and playlists. " \
            "If the user asks for a specific show date (e.g., 'Halloween 95', 'NYE 99'), " \
            "use get_show directly instead of searching. " \
            "FOLLOW-UP: If search returns a single show or user wants details about a show, " \
            "call get_show with that date to get full setlist and audio details. " \
            "DISPLAY: In markdown, link results to their url field - dates for shows, " \
            "titles for songs, names for venues/playlists. " \
            "Example: [Jul 4, 2023](show_url) or [Tweezer](song_url) or [MSG](venue_url). " \
            "Format dates readably (e.g., 'Jul 4, 2023'). " \
            "REST API: For programmatic queries beyond these tools, see https://phish.in/api/v2/swagger_doc (no API key required).",

    stats: "Statistical analysis of Phish performances. Supports gaps (bustouts), " \
           "transitions, set positions, geographic patterns, " \
           "co-occurrence, and song frequency. " \
           "DISPLAY: In markdown, link song names to their url field and dates to their track url. " \
           "Example: | [Tweezer](song_url) | 42 | [Dec 31, 1995](track_url) |. " \
           "Format dates readably (e.g., 'Jul 4, 2023'). " \
           "REST API: For custom analysis beyond built-in stats, see https://phish.in/api/v2/swagger_doc (no API key required)."
  }.freeze

  OPENAI_OVERRIDES = {
    get_audio_track: "Play a song performance with audio player widget. " \
                     "USE FOR: random track/performance requests, 'play [song]', 'listen to', " \
                     "or when user wants to hear a specific performance from get_song results. " \
                     "For random: random=true. For specific: slug='YYYY-MM-DD/track-slug'. " \
                     "WIDGET: Provide only a brief 1-2 sentence summary about the performance.",

    get_show: "Get a show with setlist widget. USE FOR RANDOM SHOW REQUESTS. " \
              "For 'random show': call with random=true. " \
              "For specific date: use date parameter. " \
              "WIDGET: Provide only a brief 1-2 sentence summary. Do NOT list tracks.",

    get_playlist: "Get detailed information about a user-created playlist and display an interactive widget. " \
                  "Returns playlist metadata and track listing with show dates and durations. " \
                  "WIDGET: If a widget is displayed, provide only a brief 1-2 sentence summary. " \
                  "Do NOT list tracks - the widget displays the full track listing.",

    list_shows: "Browse multiple shows by year, date range, tour, or venue. " \
                "Returns a list of shows WITHOUT setlists. " \
                "At least one filter is required. " \
                "FOLLOW-UP: If the result is a single show, or the user wants a random/specific show, " \
                "ALWAYS call get_show with that date to display the interactive widget with setlist and audio player. " \
                "DISPLAY: In markdown, link dates to show url and venues to venue url. " \
                "Example: | [Jul 4, 2023](show_url) | [MSG](venue_url) |. " \
                "Format dates readably (e.g., 'Jul 4, 2023').",

    search: "Search across Phish shows, songs, venues, tours, tags, and playlists. " \
            "If the user asks for a specific show date (e.g., 'Halloween 95', 'NYE 99'), " \
            "use get_show directly instead of searching. " \
            "FOLLOW-UP: If search returns a single show or user wants details about a show, " \
            "call get_show with that date to display the interactive widget. " \
            "DISPLAY: In markdown, link results to their url field - dates for shows, " \
            "titles for songs, names for venues/playlists. " \
            "Example: [Jul 4, 2023](show_url) or [Tweezer](song_url) or [MSG](venue_url). " \
            "Format dates readably (e.g., 'Jul 4, 2023')."
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
