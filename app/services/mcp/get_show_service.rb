module Mcp
  class GetShowService < ApplicationService
    option :date
    option :include_tracks, default: -> { true }
    option :include_gaps, default: -> { true }
    option :log_call, default: -> { false }

    TOOL_NAME = "get_show".freeze

    def call
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = fetch_show
      log_mcp_call(result, start_time) if log_call
      result
    end

    private

    def fetch_show
      show = find_show
      return { error: "Show not found for date: #{date}" } unless show

      build_response(show)
    end

    def find_show
      Show.includes(
        :venue,
        :tour,
        tracks: [:songs, { track_tags: :tag }],
        show_tags: :tag
      ).find_by(date: date)
    end

    def build_response(show)
      response = {
        id: show.id,
        date: show.date.iso8601,
        venue: venue_data(show),
        tour: show.tour.name,
        duration_ms: show.duration,
        duration_display: format_duration(show.duration),
        audio_status: show.audio_status,
        taper_notes: show.taper_notes,
        likes_count: show.likes_count,
        tags: show.show_tags.map { |st| tag_data(st) }
      }

      response[:tracks] = tracks_data(show) if include_tracks
      response[:navigation] = navigation_data(show)

      response
    end

    def venue_data(show)
      {
        name: show.venue_name,
        slug: show.venue.slug,
        city: show.venue.city,
        state: show.venue.state,
        country: show.venue.country
      }
    end

    def tag_data(show_tag)
      {
        name: show_tag.tag.name,
        slug: show_tag.tag.slug,
        notes: show_tag.notes
      }
    end

    def tracks_data(show)
      show.tracks.sort_by(&:position).map do |track|
        track_response = {
          position: track.position,
          title: track.title,
          slug: track.slug,
          set: track.set,
          set_name: set_name(track.set),
          duration_ms: track.duration,
          duration_display: format_duration(track.duration),
          songs: track.songs.map { |s| { title: s.title, slug: s.slug } },
          tags: track.track_tags.map { |tt| { name: tt.tag.name, notes: tt.notes } },
          likes_count: track.likes_count
        }

        if include_gaps
          songs_track = track.songs_tracks.first
          if songs_track
            track_response[:gap] = {
              previous: songs_track.previous_performance_gap,
              next: songs_track.next_performance_gap,
              previous_slug: songs_track.previous_performance_slug,
              next_slug: songs_track.next_performance_slug
            }
          end
        end

        track_response
      end
    end

    def navigation_data(show)
      {
        previous_show: previous_show_date(show.date),
        next_show: next_show_date(show.date),
        previous_show_with_audio: previous_show_date(show.date, with_audio: true),
        next_show_with_audio: next_show_date(show.date, with_audio: true)
      }
    end

    def previous_show_date(current_date, with_audio: false)
      scope = Show.where("date < ?", current_date)
      scope = scope.where(audio_status: %w[complete partial]) if with_audio
      scope.order(date: :desc).pick(:date)&.iso8601
    end

    def next_show_date(current_date, with_audio: false)
      scope = Show.where("date > ?", current_date)
      scope = scope.where(audio_status: %w[complete partial]) if with_audio
      scope.order(date: :asc).pick(:date)&.iso8601
    end

    def set_name(set_code)
      {
        "1" => "Set 1",
        "2" => "Set 2",
        "3" => "Set 3",
        "E" => "Encore",
        "E2" => "Encore 2",
        "P" => "Pre-show",
        "S" => "Soundcheck"
      }[set_code] || set_code
    end

    def format_duration(ms)
      return "0:00" unless ms&.positive?

      total_seconds = ms / 1000
      hours = total_seconds / 3600
      minutes = (total_seconds % 3600) / 60
      seconds = total_seconds % 60

      if hours > 0
        "#{hours}:#{minutes.to_s.rjust(2, '0')}:#{seconds.to_s.rjust(2, '0')}"
      else
        "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
      end
    end

    def log_mcp_call(result, start_time)
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

      McpToolCall.log_call(
        tool_name: TOOL_NAME,
        parameters: { date: date, include_tracks: include_tracks, include_gaps: include_gaps },
        result: result,
        duration_ms: duration_ms
      )
    end
  end
end





