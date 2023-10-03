module TrackHelper
  def next_gap_link(song, date) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    next_show =
      Show.joins(tracks: :songs)
          .published
          .where('date > ?', date)
          .where(songs: { id: song.id })
          .order(date: :asc)
          .first
    return if next_show.blank?

    track = next_show.tracks.includes(:songs).find { |t| song.in?(t.songs) }
    gap =
      Show.published
          .where('date BETWEEN ? AND ?', date, next_show.date)
          .count
    link_to(
      "#{tag.i(class: 'icon-forward')} Next Performance (gap: #{gap})".html_safe,
      "/#{next_show.date}/#{track.slug}"
    )
  end

  def previous_gap_link(song, date) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    prev_show =
      Show.joins(tracks: :songs)
          .published
          .where('date < ?', date)
          .where(songs: { id: song.id })
          .order(date: :desc)
          .first
    return if prev_show.blank?

    track = prev_show.tracks.includes(:songs).find { |t| song.in?(t.songs) }
    gap =
      Show.published
          .where('date BETWEEN ? AND ?', prev_show.date, date)
          .count
    link_to(
      "#{tag.i(class: 'icon-backward')} Previous Performance (gap: #{gap})".html_safe,
      "/#{prev_show.date}/#{track.slug}"
    )
  end
end
