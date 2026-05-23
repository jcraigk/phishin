module OutputSchemas
  VENUE = {
    type: "object",
    properties: {
      name: { type: "string" },
      slug: { type: %w[string null] },
      url: { type: %w[string null] },
      city: { type: %w[string null] },
      state: { type: %w[string null] },
      country: { type: %w[string null] }
    }
  }.freeze

  TAG_REF = {
    type: "object",
    properties: {
      name: { type: "string" },
      slug: { type: %w[string null] },
      description: { type: %w[string null] },
      notes: { type: %w[string null] }
    }
  }.freeze

  GAP = {
    type: %w[object null],
    properties: {
      previous: { type: %w[integer null] },
      next: { type: %w[integer null] },
      previous_slug: { type: %w[string null] },
      next_slug: { type: %w[string null] }
    }
  }.freeze

  # Widget data shape (build_widget_data) — populated for openai/anthropic clients
  GET_AUDIO_TRACK = {
    type: "object",
    description: "Audio track widget data with playback URLs, navigation, and adjacent shows",
    properties: {
      title: { type: "string" },
      slug: { type: "string" },
      url: { type: "string" },
      date: { type: "string", description: "ISO 8601 date" },
      show_url: { type: "string" },
      mp3_url: { type: %w[string null] },
      duration_ms: { type: %w[integer null] },
      waveform_image_url: { type: %w[string null] },
      venue: { type: %w[string null] },
      venue_slug: { type: %w[string null] },
      location: { type: %w[string null] },
      cover_art_url: { type: %w[string null] },
      tags: { type: "array", items: TAG_REF },
      set: { type: %w[string null] },
      position: { type: %w[integer null] },
      base_url: { type: "string" },
      current_track_index: { type: "integer" },
      is_library_start: { type: "boolean" },
      is_library_end: { type: "boolean" },
      show: { type: "object", description: "Full show data including all playable tracks" },
      prev_show: { type: %w[object null] },
      next_show: { type: %w[object null] }
    }
  }.freeze

  # Widget data shape (build_widget_data) — populated for openai/anthropic clients
  GET_SHOW = {
    type: "object",
    description: "Show widget data with full setlist, venue, tags, and album cover",
    properties: {
      date: { type: "string", description: "ISO 8601 date" },
      previous_show_date: { type: %w[string null] },
      next_show_date: { type: %w[string null] },
      venue: { type: %w[string null] },
      venue_slug: { type: %w[string null] },
      location: { type: %w[string null] },
      duration_ms: { type: %w[integer null] },
      taper_notes: { type: %w[string null] },
      cover_art_url: { type: %w[string null] },
      cover_art_url_large: { type: %w[string null] },
      album_cover_url: { type: %w[string null] },
      show_url: { type: "string" },
      tags: { type: "array", items: TAG_REF },
      tracks: {
        type: "array",
        items: {
          type: "object",
          properties: {
            title: { type: "string" },
            set: { type: %w[string null] },
            duration: { type: %w[string null] },
            duration_ms: { type: %w[integer null] },
            url: { type: "string" },
            mp3_url: { type: %w[string null] },
            waveform_image_url: { type: %w[string null] },
            song: { type: %w[object null] },
            tags: { type: "array", items: TAG_REF },
            gap: GAP
          }
        }
      }
    }
  }.freeze

  # Widget data shape (build_widget_data) — populated for openai/anthropic clients
  GET_PLAYLIST = {
    type: "object",
    description: "Playlist widget data with track listing, durations, and cover art",
    properties: {
      name: { type: "string" },
      slug: { type: "string" },
      url: { type: "string" },
      description: { type: %w[string null] },
      duration_ms: { type: %w[integer null] },
      duration_display: { type: %w[string null] },
      track_count: { type: "integer" },
      username: { type: %w[string null] },
      cover_art_url: { type: %w[string null] },
      tracks: {
        type: "array",
        items: {
          type: "object",
          properties: {
            position: { type: "integer" },
            title: { type: "string" },
            date: { type: "string" },
            show_url: { type: "string" },
            venue: { type: %w[string null] },
            venue_slug: { type: %w[string null] },
            venue_url: { type: %w[string null] },
            location: { type: %w[string null] },
            duration_ms: { type: %w[integer null] },
            duration_display: { type: %w[string null] },
            url: { type: "string" },
            mp3_url: { type: %w[string null] },
            waveform_image_url: { type: %w[string null] },
            tags: { type: "array", items: TAG_REF }
          }
        }
      }
    }
  }.freeze

  GET_SONG = {
    type: "object",
    description: "Song details with performance history",
    properties: {
      title: { type: "string" },
      slug: { type: "string" },
      url: { type: "string" },
      original: { type: "boolean" },
      artist: { type: %w[string null] },
      alias: { type: %w[string null] },
      times_played: { type: "integer" },
      first_played: { type: %w[string null] },
      last_played: { type: %w[string null] },
      performances: {
        type: "array",
        items: {
          type: "object",
          properties: {
            date: { type: "string" },
            venue: { type: %w[string null] },
            location: { type: %w[string null] },
            duration_ms: { type: %w[integer null] },
            duration_display: { type: %w[string null] },
            likes: { type: "integer" },
            set: { type: %w[string null] },
            show_url: { type: "string" },
            track_url: { type: "string" }
          }
        }
      }
    }
  }.freeze

  GET_TAG = {
    type: "object",
    description: "Tag details with associated shows or tracks",
    properties: {
      name: { type: "string" },
      slug: { type: "string" },
      group: { type: %w[string null] },
      description: { type: %w[string null] },
      shows_count: { type: "integer" },
      tracks_count: { type: "integer" },
      shows: { type: "array", items: { type: "object" } },
      tracks: { type: "array", items: { type: "object" } }
    }
  }.freeze

  GET_TOUR = {
    type: "object",
    description: "Tour metadata",
    properties: {
      name: { type: "string" },
      slug: { type: "string" },
      starts_on: { type: "string" },
      ends_on: { type: "string" },
      shows_count: { type: "integer" }
    }
  }.freeze

  GET_VENUE = {
    type: "object",
    description: "Venue details with location and performance history",
    properties: {
      name: { type: "string" },
      slug: { type: "string" },
      url: { type: "string" },
      city: { type: %w[string null] },
      state: { type: %w[string null] },
      country: { type: %w[string null] },
      location: { type: %w[string null] },
      other_names: { type: %w[array null] },
      latitude: { type: %w[number null] },
      longitude: { type: %w[number null] },
      shows_count: { type: "integer" },
      first_show: { type: %w[string null] },
      last_show: { type: %w[string null] }
    }
  }.freeze

  LIST_PLAYLISTS = {
    type: "object",
    properties: {
      total: { type: "integer" },
      playlists: {
        type: "array",
        items: {
          type: "object",
          properties: {
            name: { type: "string" },
            slug: { type: "string" },
            url: { type: "string" },
            description: { type: %w[string null] },
            duration_ms: { type: %w[integer null] },
            duration_display: { type: %w[string null] },
            tracks_count: { type: "integer" },
            likes_count: { type: "integer" },
            author: { type: %w[string null] },
            updated_at: { type: "string" }
          }
        }
      }
    }
  }.freeze

  LIST_SHOWS = {
    type: "object",
    properties: {
      total: { type: "integer" },
      filters: { type: "object" },
      shows: {
        type: "array",
        items: {
          type: "object",
          properties: {
            date: { type: "string" },
            url: { type: "string" },
            venue: { type: %w[string null] },
            venue_url: { type: %w[string null] },
            location: { type: %w[string null] },
            tour: { type: %w[string null] },
            duration_ms: { type: %w[integer null] },
            duration_display: { type: %w[string null] },
            likes: { type: "integer" },
            audio_status: { type: %w[string null] }
          }
        }
      }
    }
  }.freeze

  LIST_SONGS = {
    type: "object",
    properties: {
      total: { type: "integer" },
      songs: {
        type: "array",
        items: {
          type: "object",
          properties: {
            title: { type: "string" },
            slug: { type: "string" },
            original: { type: "boolean" },
            artist: { type: %w[string null] },
            times_played: { type: "integer" },
            url: { type: "string" }
          }
        }
      }
    }
  }.freeze

  LIST_TAGS = {
    type: "object",
    properties: {
      total: { type: "integer" },
      tags: {
        type: "array",
        items: {
          type: "object",
          properties: {
            name: { type: "string" },
            slug: { type: "string" },
            group: { type: %w[string null] },
            description: { type: %w[string null] },
            shows_count: { type: "integer" },
            tracks_count: { type: "integer" }
          }
        }
      }
    }
  }.freeze

  LIST_TOURS = {
    type: "object",
    properties: {
      total: { type: "integer" },
      tours: {
        type: "array",
        items: {
          type: "object",
          properties: {
            name: { type: "string" },
            slug: { type: "string" },
            starts_on: { type: "string" },
            ends_on: { type: "string" },
            shows_count: { type: "integer" }
          }
        }
      }
    }
  }.freeze

  LIST_VENUES = {
    type: "object",
    properties: {
      total: { type: "integer" },
      filters: { type: "object" },
      venues: {
        type: "array",
        items: {
          type: "object",
          properties: {
            name: { type: "string" },
            slug: { type: "string" },
            url: { type: "string" },
            city: { type: %w[string null] },
            state: { type: %w[string null] },
            country: { type: %w[string null] },
            location: { type: %w[string null] },
            shows_count: { type: "integer" }
          }
        }
      }
    }
  }.freeze

  LIST_YEARS = {
    type: "object",
    properties: {
      total_shows: { type: "integer" },
      total_shows_with_audio: { type: "integer" },
      years: {
        type: "array",
        items: {
          type: "object",
          properties: {
            period: { type: "string" },
            url: { type: "string" },
            era: { type: "string" },
            shows_count: { type: "integer" },
            shows_with_audio_count: { type: "integer" },
            shows_duration_ms: { type: "integer" },
            venues_count: { type: "integer" }
          }
        }
      }
    }
  }.freeze

  SEARCH = {
    type: "object",
    description: "Multi-category search results",
    properties: {
      query: { type: "string" },
      total_results: { type: "integer" },
      shows: { type: "array", items: { type: "object" } },
      songs: { type: "array", items: { type: "object" } },
      venues: { type: "array", items: { type: "object" } },
      tours: { type: "array", items: { type: "object" } },
      tags: { type: "array", items: { type: "object" } },
      tracks: { type: "array", items: { type: "object" } },
      playlists: { type: "array", items: { type: "object" } }
    }
  }.freeze

  # Stats returns one of several analysis shapes keyed by stat_type
  STATS = {
    type: "object",
    description: "Statistical analysis result. Shape varies by stat_type (gaps, transitions, set_positions, geographic, co_occurrence, song_frequency)."
  }.freeze
end
