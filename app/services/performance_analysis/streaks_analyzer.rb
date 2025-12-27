module PerformanceAnalysis
  class StreaksAnalyzer < BaseAnalyzer
    def call
      song_slug = filters[:song_slug]
      streak_type = filters[:streak_type] || "current"

      if song_slug
        analyze_song_streak(song_slug, streak_type)
      else
        analyze_active_streaks
      end
    end

    private

    def analyze_song_streak(song_slug, _streak_type)
      song = Song.find_by(slug: song_slug)
      return { error: "Song not found" } unless song

      shows_with_song_ids = Set.new(
        Show.joins(tracks: :songs)
            .where(songs: { id: song.id })
            .where.not(tracks: { set: EXCLUDED_SETS })
            .where("shows.performance_gap_value > 0")
            .distinct
            .pluck(:id)
      )

      all_shows = Show.where("performance_gap_value > 0")
                      .order(:date)
                      .pluck(:id, :date)

      streaks = find_streaks(all_shows, shows_with_song_ids)

      current_streak = calculate_current_streak_for_song(song.id)
      longest_streak = streaks.max_by { |s| s[:length] } || { length: 0 }

      {
        song: song.title,
        current_streak:,
        longest_streak: longest_streak[:length],
        longest_streak_dates: longest_streak[:length] > 0 ? "#{longest_streak[:start_date]} to #{longest_streak[:end_date]}" : nil,
        all_streaks: streaks.sort_by { |s| -s[:length] }.first(10)
      }
    end

    def calculate_current_streak_for_song(song_id)
      all_shows = Show.where("performance_gap_value > 0").order(date: :desc).pluck(:id)
      shows_with_song = Set.new(
        Track.joins(:songs)
             .where(songs: { id: song_id })
             .where.not(set: EXCLUDED_SETS)
             .where(exclude_from_stats: false)
             .pluck(:show_id)
      )

      streak = 0
      all_shows.each do |show_id|
        if shows_with_song.include?(show_id)
          streak += 1
        else
          break
        end
      end
      streak
    end

    def find_streaks(all_shows, shows_with_song_ids)
      streaks = []
      current_streak_start = nil
      current_streak_length = 0
      previous_date = nil

      all_shows.each do |show_id, date|
        if shows_with_song_ids.include?(show_id)
          current_streak_start ||= date
          current_streak_length += 1
        elsif current_streak_length > 0
          streaks << {
            start_date: current_streak_start.iso8601,
            end_date: previous_date.iso8601,
            length: current_streak_length
          }
          current_streak_start = nil
          current_streak_length = 0
        end
        previous_date = date
      end

      if current_streak_length > 0
        streaks << {
          start_date: current_streak_start.iso8601,
          end_date: all_shows.last[1].iso8601,
          length: current_streak_length
        }
      end

      streaks.select { |s| s[:length] >= 3 }
    end

    def analyze_active_streaks
      latest_show = Show.where("performance_gap_value > 0").order(date: :desc).first
      return { streaks: [] } unless latest_show

      recent_shows = Show.where("performance_gap_value > 0")
                         .order(date: :desc)
                         .limit(50)
                         .pluck(:id)

      songs_in_recent = Track.joins(:songs)
                             .where(show_id: recent_shows)
                             .where.not(set: EXCLUDED_SETS)
                             .where(exclude_from_stats: false)
                             .group("songs.id", "songs.title", "songs.slug")
                             .count

      streaks = songs_in_recent.map do |key, _|
        song_id, title, slug = key
        streak = calculate_current_streak(song_id)
        next if streak < 3

        { song: title, slug:, url: McpHelpers.song_url(slug), current_streak: streak }
      end.compact.sort_by { |s| -s[:current_streak] }.first(limit)

      { streaks:, as_of: latest_show.date.iso8601 }
    end

    def calculate_current_streak(song_id)
      all_shows = Show.where("performance_gap_value > 0").order(date: :desc).pluck(:id)
      shows_with_song = Set.new(
        Track.joins(:songs)
             .where(songs: { id: song_id })
             .where.not(set: EXCLUDED_SETS)
             .pluck(:show_id)
      )

      streak = 0
      all_shows.each do |show_id|
        if shows_with_song.include?(show_id)
          streak += 1
        else
          break
        end
      end
      streak
    end
  end
end
