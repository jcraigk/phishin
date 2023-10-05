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
    text = 'Next Performance'
    text = "#{tag.i(class: 'glyphicon glyphicon-forward')}&nbsp; #{text}(gap: #{gap})"
    link_to(text.html_safe, "/#{next_show.date}/#{track.slug}")
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
    text = 'Previous Performance'
    text = "#{tag.i(class: 'glyphicon glyphicon-backward')}&nbsp; #{text} (gap: #{gap})"
    link_to(text.html_safe, "/#{prev_show.date}/#{track.slug}")
  end
end
