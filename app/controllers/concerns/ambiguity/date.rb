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
    @sets = compose_sets
    @show_like = user_likes_for_shows([@show]).first
    @view = 'shows/show'

    hydrate_next_show
    hydrate_previous_show
  end

  def tracks_on_date
    @tracks_on_date ||= @show.tracks.sort_by(&:position)
  end

  def compose_sets
    tracks_on_date.group_by(&:set_name)
                  .each_with_object({}) do |(set, tracks), sets|
      sets[set] = {
        duration: tracks.map(&:duration).inject(0, &:+),
        tracks: tracks,
        likes: user_likes_for_tracks(tracks)
      }
    end
  end

  def fetch_show_on_date(date)
    @show = Show.includes(tracks: %i[songs tags]).find_by!(date: date)
  end

  def date_from_slug
    return false unless current_slug =~ /\A\d{4}(\-|\.)\d{1,2}(\-|\.)\d{1,2}\z/
    return current_slug.tr('-', '.') if current_slug =~ /\A(\d{4})\.(\d{1,2})\.(\d{1,2})\z/
    current_slug
  end

  def hydrate_next_show
    @next_show =
      Show.avail
          .where('date > ?', @show.date)
          .order(date: :asc)
          .first ||
      Show.avail
          .order(date: :asc)
          .first
  end

  def hydrate_previous_show
    @previous_show =
      Show.avail
          .where('date < ?', @show.date)
          .order(date: :desc)
          .first ||
      Show.avail
          .order(date: :desc)
          .first
  end
end
