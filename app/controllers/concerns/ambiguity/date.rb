# frozen_string_literal: true
module Ambiguity::Date
  def slug_as_date
    return false unless date_from_slug.present?

    fetch_show_on_date(date_from_slug)
    hydrate_page_for_date

    true
  end

  private

  def hydrate_page_for_date
    @sets = compose_sets_for_date
    @show_like = user_likes_for_shows([@show]).first
    @previous_show = previous_show
    @next_show = next_show

    @view = 'shows/show'
  end

  def compose_sets_for_date
    @show.tracks
         .sort_by(&:position)
         .group_by(&:set_name)
         .each_with_object({}) do |(set, tracks), sets|
           sets[set] = tracks_as_set(tracks)
         end
  end

  def tracks_as_set(tracks)
    {
      duration: tracks.map(&:duration).inject(0, &:+),
      tracks: tracks,
      likes: user_likes_for_tracks(tracks)
    }
  end

  def fetch_show_on_date(date)
    @show = Show.includes(:venue, tracks: [:songs, { track_tags: :tag }]).find_by!(date: date)
  end

  def date_from_slug
    return false unless current_slug =~ /\A\d{4}(\-|\.)\d{1,2}(\-|\.)\d{1,2}\z/
    return current_slug.tr('-', '.') if current_slug =~ /\A(\d{4})\.(\d{1,2})\.(\d{1,2})\z/
    current_slug
  end

  def previous_show
    Show.where('date < ?', @show.date)
        .order(date: :desc)
        .first ||
      Show.order(date: :desc)
          .first
  end

  def next_show
    Show.where('date > ?', @show.date)
        .order(date: :asc)
        .first ||
      Show.order(date: :asc)
          .first
  end
end
