class MetaTagService < ApplicationService
  param :path

  TITLE_SUFFIX = " - #{App.app_name}"
  BASE_TITLE = App.app_name
  DEFAULT_DESCRIPTION = App.app_desc

  HOME_TITLE = "Phish.in - Stream Live Phish Free | Audience Recordings & Setlists"
  HOME_DESCRIPTION =
    "Stream free live Phish audio. Phish.in is an open source archive of audience " \
    "recordings with complete setlists, song stats, and downloads for every show " \
    "from 1983 to today."

  RESOURCES = {
    "play" => Playlist,
    "songs" => Song,
    "tags" => Tag,
    "venues" => Venue
  }

  TITLES = {
    "/api-docs" => "API Docs",
    "/contact-info" => "Contact Info",
    "/draft-playlist" => "Draft Playlist",
    "/playlists" => "Playlists",
    "/faq" => "FAQ",
    "/login" => "Login",
    "/map" => "Map",
    "/missing-content" => "Missing Content Report",
    "/my-shows" => "My Shows",
    "/my-tracks" => "My Tracks",
    "/privacy" => "Privacy Policy",
    "/request-password-reset" => "Reset Password",
    "/reset-password/:token" => "Reset Password",
    "/search" => "Search",
    "/settings" => "Settings",
    "/signup" => "Sign Up",
    "/tagin-project" => "Tagin' Project",
    "/terms" => "Terms of Service",
    "/today" => "Today in History",
    "/top-shows" => "Top Shows",
    "/top-tracks" => "Top Tracks"
  }

  SEO_TITLES = {
    "/top-shows" => "Best Phish Shows#{TITLE_SUFFIX}",
    "/top-tracks" => "Best Phish Tracks#{TITLE_SUFFIX}"
  }

  DESCRIPTIONS = {
    "/top-shows" =>
      "The highest-rated live Phish shows of all time, ranked by fans. Stream the " \
      "best concerts with full setlists and free audience recordings.",
    "/top-tracks" =>
      "The highest-rated live Phish tracks, ranked by fans. Listen to the best jams " \
      "and song performances for free.",
    "/today" =>
      "Phish shows that happened on this day in history. Stream free live audio from " \
      "past concerts performed on today's date.",
    "/map" =>
      "Explore every venue Phish has played on an interactive map. Find shows by city, " \
      "state, and country with free streaming audio.",
    "/playlists" =>
      "Browse and create custom Phish playlists. Stream curated collections of live " \
      "tracks and audience recordings for free.",
    "/search" =>
      "Search the complete Phish.in archive of live audio. Find shows, songs, venues, " \
      "and tracks with free streaming.",
    "/faq" =>
      "Frequently asked questions about Phish.in, the open source archive of free live " \
      "Phish audience recordings."
  }

  INDEX_META = {
    "songs" => {
      title: "Phish Songs",
      description:
        "Browse every song Phish has performed live. Find all versions of each song " \
        "with audio, dates, venues, and play counts. Stream free."
    },
    "venues" => {
      title: "Phish Venues",
      description:
        "Browse every venue Phish has played, from clubs to arenas. Find shows by " \
        "location with setlists and free streaming audio."
    },
    "tags" => {
      title: "Phish Tags",
      description:
        "Browse Phish shows and tracks by tag. Find jams, debuts, and notable moments " \
        "with free streaming live audio."
    }
  }

  def call
    meta_tag_data
  end

  private

  def meta_tag_data
    return home_meta_data if path == "/"
    return hardcoded_meta_data if hard_coded_title
    return dynamic_meta_data if date? || year? || year_range?
    return playlist_data if playlist?
    return tag_data if tag_related?
    return song_data if song?
    return venue_data if venue?

    index_meta_data || not_found_meta
  end

  def home_meta_data
    { title: HOME_TITLE, description: HOME_DESCRIPTION, og: {}, status: :ok }
  end

  def hard_coded_title
    TITLES[path] || dynamic_route_title
  end

  def dynamic_route_title
    "Reset Password" if path.match?(/^\/reset-password\/.+/)
  end

  def index_meta_data
    meta = INDEX_META[resource_type]
    return nil unless meta
    { title: "#{meta[:title]}#{TITLE_SUFFIX}", description: meta[:description], og: {}, status: :ok }
  end

  def hardcoded_meta_data
    {
      title: SEO_TITLES[path] || "#{hard_coded_title}#{TITLE_SUFFIX}",
      description: DESCRIPTIONS[path] || DEFAULT_DESCRIPTION,
      og: {},
      status: :ok
    }
  end

  def dynamic_meta_data
    if date?
      show_data
    elsif year?
      year_data
    elsif year_range?
      year_range_data
    end
  end

  def playlist_data
    return index_meta_data || not_found_meta if slug.nil?

    playlist = Playlist.includes(:tracks).find_by(slug:)
    return not_found_meta if playlist.nil?

    track = playlist.tracks.order(:position).first
    {
      title: "Listen to #{playlist.name}#{TITLE_SUFFIX}",
      description:
        "Listen to \"#{playlist.name}\", a custom Phish playlist on Phish.in. " \
        "Stream free live audio tracks.",
      og: {
        title: "Listen to #{playlist.name}",
        description: "A custom Phish playlist, free to stream.",
        type: "music.playlist",
        audio: track&.mp3_url,
        image: track&.show&.cover_art_urls&.dig(:medium)
      },
      status: :ok
    }
  end

  def show_data
    show = Show.includes(:venue, :tracks).find_by(date:)
    return not_found_meta unless show

    track = slug ? show.tracks.find_by(slug:) : nil
    track ? track_show_meta(show, track) : default_show_meta(show)
  end

  def track_show_meta(show, track)
    {
      title: "#{track.title} by Phish - #{short_date(show.date)}#{TITLE_SUFFIX}",
      description:
        "Phish's live performance of #{track.title} at #{venue_phrase(show)} on " \
        "#{long_date(show.date)}. A free audience recording you can stream or download.",
      og: {
        title: "Listen to Phish perform #{track.title} on #{long_date(show.date)}",
        description: "Stream or download this performance for free.",
        type: "music.playlist",
        audio: show.tracks.order(:position).first&.mp3_url,
        image: show.cover_art_urls[:medium]
      },
      status: :ok
    }
  end

  def default_show_meta(show)
    {
      title: "Phish at #{show.venue_name}, #{short_date(show.date)}#{TITLE_SUFFIX}",
      description:
        "Stream Phish's full show from #{long_date(show.date)} at #{venue_phrase(show)}. " \
        "A free audience recording with the complete setlist and audio for every track.",
      og: {
        title: "Listen to Phish perform at #{show.venue_name} on #{long_date(show.date)}",
        description: "A complete live audience recording, free to stream or download.",
        type: "music.playlist",
        audio: show.tracks.order(:position).first&.mp3_url,
        image: show.cover_art_urls[:medium]
      },
      status: :ok
    }
  end

  def year_data
    year = segments[0].to_i
    return not_found_meta if shows_in_year(year).none?

    {
      title: "Phish #{year}#{TITLE_SUFFIX}",
      description:
        "Browse every Phish show from #{year}. Stream free audience recordings with " \
        "complete setlists and audio for every track.",
      og: {
        title: "Listen to shows from #{year}",
        description: "Browse every show from this year, free to stream or download.",
        type: "music.playlist"
      },
      status: :ok
    }
  end

  def year_range_data
    start_year, end_year = segments[0].split("-").map(&:to_i)
    return not_found_meta if shows_in_range(start_year, end_year).none?

    {
      title: "Phish #{start_year}-#{end_year}#{TITLE_SUFFIX}",
      description:
        "Browse Phish shows from #{start_year} to #{end_year}. Stream free audience " \
        "recordings with setlists and live audio.",
      og: {},
      status: :ok
    }
  end

  def tag_data
    tag = Tag.find_by(slug:)
    return not_found_meta unless tag

    scope = resource_type == "show-tags" ? "Shows" : "Tracks"
    {
      title: "#{tag.name} - #{scope}#{TITLE_SUFFIX}",
      description:
        "Phish #{scope.downcase} tagged \"#{tag.name}\". Browse and stream tagged live " \
        "audio for free.",
      og: {},
      status: :ok
    }
  end

  def song_data
    return index_meta_data || not_found_meta if slug.nil?

    song = Song.find_by(slug:)
    return not_found_meta unless song

    {
      title: "#{song.name} by Phish#{TITLE_SUFFIX}",
      description:
        "Listen to every performance of #{song.name} by Phish, with audio, dates, " \
        "venues, and play counts. Stream or download for free.",
      og: {
        title: "Listen to Phish perform #{song.name}",
        description: "Browse every performance with dates, venues, and play counts, all free to stream or download.",
        image: false
      },
      status: :ok
    }
  end

  def venue_data
    return index_meta_data || not_found_meta if slug.nil?

    venue = Venue.find_by(slug:)
    return not_found_meta unless venue

    {
      title: "Phish at #{venue.name}#{TITLE_SUFFIX}",
      description:
        "Every Phish show at #{venue.name} in #{venue.location}. Browse all performances " \
        "with setlists and free streaming audio.",
      og: {
        title: "Listen to Phish perform at #{venue.name}",
        description: "Browse every Phish show at this venue, free to stream or download.",
        image: false
      },
      status: :ok
    }
  end

  def not_found_meta
    { title: "404 - Phish.in", description: DEFAULT_DESCRIPTION, og: {}, status: :not_found }
  end

  def venue_phrase(show)
    location = show.venue&.location
    location.present? ? "#{show.venue_name} in #{location}" : show.venue_name
  end

  def shows_in_year(year)
    Show.where("EXTRACT(YEAR FROM date) = ?", year)
  end

  def shows_in_range(start_year, end_year)
    Show.where("EXTRACT(YEAR FROM date) BETWEEN ? AND ?", start_year, end_year)
  end

  def short_date(date)
    date.strftime("%b %-d, %Y")
  end

  def long_date(date)
    date.strftime("%B %-d, %Y")
  end

  def date?
    segments[0] =~ /^\d{4}-\d{2}-\d{2}$/
  end

  def date
    return nil unless date?
    @date ||= begin
      Date.parse(segments[0])
    rescue Date::Error
      nil
    end
  end

  def year?
    segments[0] =~ /^\d{4}$/ && !slug
  end

  def year_range?
    segments[0] =~ /^\d{4}-\d{4}$/ && !slug
  end

  def playlist?
    resource_type == "play"
  end

  def tag_related?
    resource_type.in?(%w[show-tags track-tags])
  end

  def song?
    resource_type == "songs"
  end

  def venue?
    resource_type == "venues"
  end

  def segments
    @segments ||= path.split("/").reject(&:empty?)
  end

  def resource_type
    @resource_type ||= segments[0]
  end

  def slug
    @slug ||= segments[1]
  end
end
