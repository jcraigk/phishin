module PerformanceAnalysis
  class TransitionsAnalyzer < BaseAnalyzer
    def call
      song_slug = filters[:song_slug]
      direction = filters[:direction] || "after"

      if song_slug
        analyze_song_transitions(song_slug, direction)
      else
        analyze_common_transitions
      end
    end

    private

    def analyze_song_transitions(song_slug, direction)
      song = Song.find_by(slug: song_slug)
      return { error: "Song not found" } unless song

      tracks_with_song = Track.joins(:songs, :show)
                              .where(songs: { id: song.id })
                              .where.not(set: EXCLUDED_SETS)
                              .where(exclude_from_stats: false)
                              .includes(:show)

      transitions = {}

      tracks_with_song.find_each do |track|
        adjacent_track = if direction == "after"
          Track.where(show_id: track.show_id)
               .where("position > ?", track.position)
               .where.not(set: EXCLUDED_SETS)
               .order(:position)
               .first
        else
          Track.where(show_id: track.show_id)
               .where("position < ?", track.position)
               .where.not(set: EXCLUDED_SETS)
               .order(position: :desc)
               .first
        end

        next unless adjacent_track

        adjacent_track.songs.each do |adjacent_song|
          transitions[adjacent_song.slug] ||= { song: adjacent_song.title, slug: adjacent_song.slug, url: adjacent_song.url, count: 0 }
          transitions[adjacent_song.slug][:count] += 1
        end
      end

      total = transitions.values.sum { |t| t[:count] }
      results = transitions.values
                           .map { |t| t.merge(percentage: total > 0 ? (t[:count].to_f / total * 100).round(1) : 0) }
                           .sort_by { |t| -t[:count] }
                           .first(limit)

      {
        song: song.title,
        url: song.url,
        direction:,
        total_transitions: total,
        transitions: results
      }
    end

    def analyze_common_transitions
      transition_counts = Hash.new(0)

      Show.includes(tracks: :songs)
          .where("performance_gap_value > 0")
          .find_each do |show|
        tracks = show.tracks.where.not(set: EXCLUDED_SETS)
                     .where(exclude_from_stats: false)
                     .order(:position)

        tracks.each_cons(2) do |track1, track2|
          track1.songs.each do |song1|
            track2.songs.each do |song2|
              key = "#{song1.slug}->#{song2.slug}"
              transition_counts[key] += 1
            end
          end
        end
      end

      results = transition_counts.map do |key, count|
        from_slug, to_slug = key.split("->")
        from_song = Song.find_by(slug: from_slug)
        to_song = Song.find_by(slug: to_slug)
        next unless from_song && to_song

        {
          from: from_song.title,
          from_slug:,
          to: to_song.title,
          to_slug:,
          count:
        }
      end.compact.sort_by { |r| -r[:count] }.first(limit)

      { transitions: results }
    end
  end
end
