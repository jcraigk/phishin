module Ambiguity::Date
  def slug_as_date
    return false if date_from_slug.blank?

    fetch_show_on_date(date_from_slug)
    hydrate_page_for_date

    true
  end

  private

  def hydrate_page_for_date
    assign_ogp_values
    @sets = compose_sets_for_date
    @show_like = user_likes_for_shows([ @show ]).first
    @previous_show = previous_show
    @next_show = next_show

    @view = "shows/show"
  end

  def assign_ogp_values
    date = Date.parse(current_slug).strftime("%B %-d, %Y")
    @ogp_audio_url = selected_track&.mp3_url
    @ogp_title =
      if params[:anchor].present? && selected_track.present?
        "Listen to #{selected_track.title} from #{date}"
      else
        @ogp_title = "Listen to #{date}"
      end
  end

  def selected_track
    tracks =
      Track.joins(:show)
           .where(show: { date: current_slug })
           .order(:position)
    tracks = tracks.where(slug: params[:anchor]) if params[:anchor].present?
    tracks.first
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
      duration: tracks.sum(&:duration),
      tracks:,
      likes: user_likes_for_tracks(tracks)
    }
  end

  def fetch_show_on_date(date)
    @show =
      Show.published
          .includes(:venue, tracks: [ :songs, { track_tags: :tag } ])
          .find_by!(date:)
  end

  def date_from_slug
    return false unless current_slug.match?(/\A\d{4}(-|\.)\d{1,2}(-|\.)\d{1,2}\z/)
    return current_slug.tr(".", "-") if current_slug.match?(/\A(\d{4})\.(\d{1,2})\.(\d{1,2})\z/)
    current_slug
  end

  def previous_show
    Show.published
        .where(date: ...@show.date)
        .order(date: :desc)
        .first ||
      Show.published
          .order(date: :desc)
          .first
  end

  def next_show
    Show.published
        .where("date > ?", @show.date)
        .order(date: :asc)
        .first ||
      Show.published
          .order(date: :asc)
          .first
  end
end
