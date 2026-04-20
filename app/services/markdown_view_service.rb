class MarkdownViewService < ApplicationService
  include ActionView::Helpers::NumberHelper

  param :path

  def call
    return homepage_markdown if segments.empty?
    return show_markdown if date? && slug.nil?
    return track_markdown if date? && slug.present?
    return song_markdown if resource_type == "songs" && slug.present?
    return venue_markdown if resource_type == "venues" && slug.present?
    return playlist_markdown if resource_type == "play" && slug.present?
    return year_markdown if year?

    llms_txt_fallback
  end

  private

  def homepage_markdown
    shows_count = Show.count
    tracks_count = Track.count
    songs_count = Song.count
    venues_count = Venue.count
    first_year = Show.order(:date).limit(1).pick(:date)&.year
    last_year = Show.order(date: :desc).limit(1).pick(:date)&.year

    <<~MD
      # #{App.app_name}

      > #{App.app_desc}.

      Live Phish audio archive covering **#{number_with_delimiter(shows_count)} shows** and
      **#{number_with_delimiter(tracks_count)} tracks** from
      **#{number_with_delimiter(venues_count)} venues** (#{first_year}-#{last_year}).
      All audio is sourced from public taper uploads and complies with Phish's
      official taping policy.

      ## Interfaces

      - Web: <#{App.base_url}>
      - JSON API v2 (OpenAPI): <#{App.base_url}/api/v2/swagger_doc>
      - MCP (Claude): <#{App.base_url}/mcp/anthropic>
      - MCP (ChatGPT): <#{App.base_url}/mcp/openai>
      - MCP (default): <#{App.base_url}/mcp>
      - Agent summary: <#{App.base_url}/llms.txt>
      - Sitemap: <#{App.base_url}/sitemap.xml>

      ## Browse

      - `/YYYY-MM-DD` — a single show (e.g. `/1997-11-22`)
      - `/YYYY-MM-DD/track-slug` — a single track
      - `/songs/:slug` — song with performance history (#{number_with_delimiter(songs_count)} songs)
      - `/venues/:slug` — venue with show list (#{number_with_delimiter(venues_count)} venues)
      - `/:year` — year index
      - `/play/:slug` — user-created playlist

      All pages also respond to `Accept: text/markdown` for agent-friendly access.
    MD
  end

  def show_markdown
    show = Show.includes(tracks: { track_tags: :tag }, show_tags: :tag, venue: {}).find_by(date:)
    return not_found("Show not found for #{date}") unless show

    lines = []
    lines << "# Phish — #{long_date(show.date)}"
    lines << ""
    lines << "- Venue: [#{show.venue_name}](#{show.venue&.url || App.base_url}) (#{show.venue&.location})"
    lines << "- Tour: #{show.tour&.name}" if show.tour
    lines << "- Duration: #{format_duration(show.duration)}" if show.duration
    lines << "- Audio: #{show.audio_status}"
    lines << "- URL: <#{show.url}>"
    if show.show_tags.any?
      lines << "- Tags: #{show.show_tags.map { |st| st.tag.name }.uniq.join(', ')}"
    end
    lines << ""
    lines << "## Setlist"
    lines << ""
    by_set = show.tracks.order(:position).group_by(&:set_name)
    by_set.each do |set_name, tracks|
      lines << "### #{set_name}"
      tracks.each do |t|
        tag_names = t.track_tags.map { |tt| tt.tag.name }.uniq
        suffix = tag_names.any? ? "  _(#{tag_names.join(', ')})_" : ""
        lines << "- [#{t.title}](#{t.url}) — #{format_duration(t.duration)}#{suffix}"
      end
      lines << ""
    end
    lines.join("\n")
  end

  def track_markdown
    show = Show.find_by(date:)
    return not_found("Show not found for #{date}") unless show
    track = show.tracks.includes(:songs, track_tags: :tag).find_by(slug:)
    return not_found("Track not found: #{slug}") unless track

    <<~MD
      # #{track.title} — #{long_date(show.date)}

      - Show: [#{long_date(show.date)}](#{show.url}) at [#{show.venue_name}](#{show.venue&.url})
      - Duration: #{format_duration(track.duration)}
      - Set: #{track.set_name}
      - Position: #{track.position}
      - URL: <#{track.url}>
      #{track.track_tags.any? ? "- Tags: #{track.track_tags.map { |tt| tt.tag.name }.uniq.join(', ')}" : ''}
    MD
  end

  def song_markdown
    song = Song.find_by(slug:)
    return not_found("Song not found: #{slug}") unless song

    recent = song.tracks.includes(:show).joins(:show).order("shows.date DESC").limit(10)
    lines = []
    lines << "# #{song.title}"
    lines << ""
    lines << "- Original: #{song.original ? 'Yes' : 'No (cover)'}"
    lines << "- Artist: #{song.artist}" if song.artist.present?
    lines << "- Performances: #{song.tracks_count}"
    lines << "- URL: <#{song.url}>"
    lines << ""
    if recent.any?
      lines << "## Recent performances"
      lines << ""
      recent.each do |t|
        lines << "- [#{long_date(t.show.date)}](#{t.url}) — #{format_duration(t.duration)}"
      end
    end
    lines.join("\n")
  end

  def venue_markdown
    venue = Venue.find_by(slug:)
    return not_found("Venue not found: #{slug}") unless venue

    <<~MD
      # #{venue.name}

      - Location: #{venue.location}
      - Shows hosted: #{venue.shows_count}
      - URL: <#{venue.url}>
    MD
  end

  def playlist_markdown
    playlist = Playlist.includes(tracks: :show).find_by(slug:)
    return not_found("Playlist not found: #{slug}") unless playlist

    lines = []
    lines << "# #{playlist.name}"
    lines << ""
    lines << "- By: #{playlist.user&.username}" if playlist.respond_to?(:user)
    lines << "- Tracks: #{playlist.playlist_tracks.size}"
    lines << "- Duration: #{format_duration(playlist.duration)}"
    lines << "- URL: <#{playlist.url}>"
    lines << ""
    lines << "## Tracks"
    lines << ""
    playlist.tracks.each do |t|
      lines << "- [#{t.title} (#{long_date(t.show.date)})](#{t.url}) — #{format_duration(t.duration)}"
    end
    lines.join("\n")
  end

  def year_markdown
    year = segments[0].to_i
    shows = Show.where("EXTRACT(YEAR FROM date) = ?", year).order(:date)
    return not_found("No shows in #{year}") if shows.empty?

    lines = [ "# Phish #{year}", "", "- Shows: #{shows.size}", "" ]
    shows.limit(200).each do |show|
      lines << "- [#{long_date(show.date)}](#{show.url}) — #{show.venue_name}"
    end
    lines.join("\n")
  end

  def llms_txt_fallback
    path = Rails.root.join("public", "llms.txt")
    File.exist?(path) ? File.read(path) : "# #{App.app_name}\n\nSee <#{App.base_url}>."
  end

  def not_found(message)
    "# Not found\n\n#{message}\n"
  end

  def long_date(d)
    d.strftime("%b %-d, %Y")
  end

  def format_duration(ms)
    return "?" unless ms
    total = ms.to_i / 1000
    minutes = total / 60
    seconds = total % 60
    format("%d:%02d", minutes, seconds)
  end

  def segments
    @segments ||= path.to_s.split("/").reject(&:empty?)
  end

  def resource_type
    segments[0]
  end

  def slug
    segments[1]
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
    segments[0] =~ /^\d{4}$/ && slug.nil?
  end
end
