class MetaTagService < ApplicationService
  param :path

  TITLE_SUFFIX = " - #{App.app_name}"
  BASE_TITLE = App.app_name

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

  def call
    meta_tag_data
  end

  private

  def meta_tag_data
    return { title: BASE_TITLE, status: :ok } if path == "/"
    return hardcoded_meta_data if hard_coded_title
    return dynamic_meta_data if date? || year? || year_range?
    return playlist_data if playlist?
    return tag_data if tag_related?
    return song_data if song?
    return venue_data if venue?

    { title: resource_title || BASE_TITLE, og: {}, status: resource_title ? :ok : :not_found }
  end

  def hard_coded_title
    TITLES[path] || dynamic_route_title
  end

  def dynamic_route_title
    "Reset Password" if path.match?(/^\/reset-password\/.+/)
  end

  def resource_title
    klass = RESOURCES[resource_type]
    if klass
      if slug
        resource_name(klass)
      else
        "#{resource_type.capitalize}#{TITLE_SUFFIX}"
      end
    else
      nil
    end
  end

  def resource_name(klass)
    resource = klass.find_by(slug:)
    resource&.name || "404 - Phish.in"
  end

  def hardcoded_meta_data
    { title: "#{hard_coded_title}#{TITLE_SUFFIX}", og: {}, status: :ok }
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
    return { title: "Playlists#{TITLE_SUFFIX}", og: {}, status: :not_found } if slug.nil?

    playlist = Playlist.includes(:tracks).find_by(slug:)
    return { title: "404 - Phish.in", og: {}, status: :not_found } if playlist.nil?

    track = playlist.tracks.order(:position).first
    {
      title: "Listen to #{playlist.name}#{TITLE_SUFFIX}",
      og: {
        title: "Listen to #{playlist.name}",
        type: "music.playlist",
        audio: track&.mp3_url,
        image: track&.show&.album_cover_url
      },
      status: :ok
    }
  end

  def show_data
    show = Show.includes(:tracks).find_by(date:)
    return not_found_meta unless show

    if slug
      track = show.tracks.find_by(slug:)
      if track
        title = "#{track.title} - #{short_date(show.date)}#{TITLE_SUFFIX}"
        og_title = "Listen to #{track.title} from #{long_date(show.date)}"
      else
        title = "#{short_date(show.date)}#{TITLE_SUFFIX}"
        og_title = "Listen to #{long_date(show.date)}"
      end
      {
        title:,
        og: {
          title: og_title,
          type: "music.playlist",
          audio: show.tracks.order(:position).first&.mp3_url,
          image: show&.album_cover_url
        },
        status: :ok
      }
    else
      default_show_meta(show)
    end
  end

  def default_show_meta(show)
    {
      title: "#{short_date(show.date)}#{TITLE_SUFFIX}",
      og: {
        title: "Listen to #{long_date(show.date)}",
        type: "music.playlist",
        audio: show.tracks.order(:position).first&.mp3_url,
        image: show&.album_cover_url
      },
      status: :ok
    }
  end

  def year_data
    year = segments[0].to_i
    shows = Show.where("EXTRACT(YEAR FROM date) = ?", year)
    if shows.present?
      {
        title: "#{year}#{TITLE_SUFFIX}",
        og: {
          title: "Listen to shows from #{year}",
          type: "music.playlist"
        },
        status: :ok
      }
    else
      not_found_meta
    end
  end

  def year_range_data
    start_year, end_year = segments[0].split("-").map(&:to_i)
    shows = Show.where("EXTRACT(YEAR FROM date) BETWEEN ? AND ?", start_year, end_year)
    if shows.present?
      { title: "#{start_year}-#{end_year}#{TITLE_SUFFIX}", og: {}, status: :ok }
    else
      not_found_meta
    end
  end

  def tag_data
    tag = Tag.find_by(slug:)
    return not_found_meta unless tag

    title_suffix = resource_type == "show-tags" ? "Shows" : "Tracks"
    {
      title: "#{tag.name} - #{title_suffix}#{TITLE_SUFFIX}",
      og: {},
      status: :ok
    }
  end

  def song_data
    return { title: "Songs#{TITLE_SUFFIX}", og: {}, status: :ok } if slug.nil?

    song = Song.find_by(slug:)
    return not_found_meta unless song

    {
      title: "#{song.name}#{TITLE_SUFFIX}",
      og: {
        title: "Explore performances of #{song.name}",
        card_type: :summary
      },
      status: :ok
    }
  end

  def venue_data
    return { title: "Venues#{TITLE_SUFFIX}", og: {}, status: :ok } if slug.nil?

    venue = Venue.find_by(slug:)
    return not_found_meta unless venue

    {
      title: "#{venue.name}#{TITLE_SUFFIX}",
      og: {
        title: "Explore shows at #{venue.name}",
        card_type: :summary
      },
      status: :ok
    }
  end

  def not_found_meta
    { title: "404 - Phish.in", og: {}, status: :not_found }
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
