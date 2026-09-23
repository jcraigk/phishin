class CrawlableContentService < ApplicationService
  param :path

  DATE_PATTERN = /\A\d{4}-\d{2}-\d{2}\z/
  YEAR_PATTERN = /\A\d{4}\z/

  def call
    return show_or_track_content if segments[0]&.match?(DATE_PATTERN)
    return year_content if segments.one? && segments[0].match?(YEAR_PATTERN)
    return song_content if resource_type == "songs" && slug
    venue_content if resource_type == "venues" && slug
  end

  private

  def show_or_track_content
    return if segments.size > 2

    show = Show.published.includes(:venue, :tour, tracks: :songs).find_by(date: segments[0])
    return unless show
    return { partial: "crawlable/show", locals: { show: } } unless slug

    track = show.tracks.find { |t| t.slug == slug }
    { partial: "crawlable/track", locals: { show:, track: } } if track
  end

  def year_content
    year = segments[0].to_i
    shows = Show.published.includes(:venue).where("EXTRACT(YEAR FROM date) = ?", year).order(:date)
    { partial: "crawlable/year", locals: { year:, shows: } } if shows.any?
  end

  def song_content
    song = Song.find_by(slug:)
    return unless song

    tracks = song.tracks.joins(:show).merge(Show.published).includes(:show).order("shows.date")
    { partial: "crawlable/song", locals: { song:, tracks: } }
  end

  def venue_content
    venue = Venue.find_by(slug:)
    return unless venue

    { partial: "crawlable/venue", locals: { venue:, shows: venue.shows.published.order(:date) } }
  end

  def segments
    @segments ||= path.split("/").reject(&:empty?)
  end

  def resource_type
    segments[0]
  end

  def slug
    segments[1]
  end
end
