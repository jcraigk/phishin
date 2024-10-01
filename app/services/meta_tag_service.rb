class MetaTagService < BaseService
  extend Dry::Initializer

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
    if path == "/"
      { title: BASE_TITLE, status: :ok }
    elsif hard_coded_title
      { title: "#{hard_coded_title}#{TITLE_SUFFIX}", og: {}, status: :ok }
    elsif date?
      show_data
    elsif year?
      year_data
    elsif year_range?
      year_range_data
    elsif playlist?
      playlist_data
    elsif tag_related?
      tag_data
    else
      { title: resource_title || BASE_TITLE, og: {}, status: resource_title ? :ok : :not_found }
    end
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
      slug ? resource_name(klass) : "#{resource_type.capitalize}#{TITLE_SUFFIX}"
    end
  end

  def resource_name(klass)
    resource = klass.find_by(slug:)
    resource&.name || "404 - Phish.in"
  end

  def playlist_data
    return { title: "Playlists#{TITLE_SUFFIX}", og: {}, status: :not_found } if slug.nil?

    playlist = Playlist.includes(:tracks).find_by(slug:)
    return { title: "404 - Phish.in", og: {}, status: :not_found } if playlist.nil?

    {
      title: "Listen to #{playlist.name}#{TITLE_SUFFIX}",
      og: {
        title: "Listen to #{playlist.name}",
        type: "music.playlist",
        audio: playlist.tracks.order(:position).first&.mp3_url
      },
      status: :ok
    }
  end

  def show_data
    show = Show.includes(:tracks).find_by(date: date)
    return { title: "404 - Phish.in", og: {}, status: :not_found } if show.nil?

    if slug
      track = show.tracks.find_by(slug: slug)
      title =
        if track
          "#{track.title} - #{formatted_date(show.date)}#{TITLE_SUFFIX}"
        else
          "#{formatted_date(show.date)}#{TITLE_SUFFIX}"
        end
      og_title =
        if track
          "Listen to #{track.title} from #{long_date_format(show.date)}"
        else
          "Listen to #{long_date_format(show.date)}"
        end
    else
      title = "#{formatted_date(show.date)}#{TITLE_SUFFIX}"
      og_title = "Listen to #{long_date_format(show.date)}"
    end

    {
      title:,
      og: {
        title: og_title,
        type: "music.playlist",
        audio: show.tracks.order(:position).first&.mp3_url
      },
      status: :ok
    }
  end

  def year_data
    year = segments[0].to_i
    shows = Show.where("EXTRACT(YEAR FROM date) = ?", year)
    return { title: "404 - Phish.in", og: {}, status: :not_found } if shows.empty?

    { title: "#{year}#{TITLE_SUFFIX}", og: {}, status: :ok }
  end

  def year_range_data
    start_year, end_year = segments[0].split("-").map(&:to_i)
    shows = Show.where("EXTRACT(YEAR FROM date) BETWEEN ? AND ?", start_year, end_year)
    return { title: "404 - Phish.in", og: {}, status: :not_found } if shows.empty?

    { title: "#{start_year}-#{end_year}#{TITLE_SUFFIX}", og: {}, status: :ok }
  end

  def tag_data
    tag = Tag.find_by(slug: slug)
    return { title: "404 - Phish.in", og: {}, status: :not_found } if tag.nil?

    title_suffix = resource_type == "show-tags" ? "Shows" : "Tracks"
    {
      title: "#{tag.name} - #{title_suffix}#{TITLE_SUFFIX}",
      og: {},
      status: :ok
    }
  end

  def formatted_date(date)
    date.strftime("%Y.%m.%d")
  end

  def long_date_format(date)
    date.strftime("%B %-d, %Y")
  end

  def date?
    segments[0] =~ /^\d{4}-\d{2}-\d{2}$/
  end

  def date
    @date ||= Date.parse(segments[0]) if date?
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
