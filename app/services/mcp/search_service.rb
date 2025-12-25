module Mcp
  class SearchService < ApplicationService
    option :query
    option :limit, default: -> { 25 }
    option :log_call, default: -> { false }

    TOOL_NAME = "search".freeze
    MIN_QUERY_LENGTH = 2

    def call
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = perform_search
      log_mcp_call(result, start_time) if log_call
      result
    end

    private

    def perform_search
      return { error: "Query must be at least #{MIN_QUERY_LENGTH} characters" } if query.to_s.length < MIN_QUERY_LENGTH

      results = {
        shows: search_shows,
        songs: transform_songs(main_search_results[:songs] || []),
        venues: transform_venues(main_search_results[:venues] || []),
        tags: transform_tags(main_search_results[:tags] || []),
        playlists: transform_playlists(main_search_results[:playlists] || []),
        query: query,
        total_results: 0
      }

      results[:total_results] = results.except(:query, :total_results).values.flatten.count
      results
    end

    def main_search_results
      @main_search_results ||= ::SearchService.call(term: query, scope: "all") || {}
    end

    def search_shows
      raw = main_search_results
      shows = []

      if raw[:exact_show]
        shows << show_result(raw[:exact_show])
      end

      (raw[:other_shows] || []).first(limit).each do |show|
        shows << show_result(show)
      end

      shows.first(limit)
    end

    def transform_songs(songs)
      songs.first(limit).map { |song| song_result(song) }
    end

    def transform_venues(venues)
      venues.first(limit).map { |venue| venue_result(venue) }
    end

    def transform_tags(tags)
      tags.first(limit).map { |tag| tag_result(tag) }
    end

    def transform_playlists(playlists)
      playlists.first(limit).map { |playlist| playlist_result(playlist) }
    end

    def show_result(show)
      {
        type: "show",
        date: show.date.iso8601,
        venue_name: show.venue_name,
        location: show.venue&.location,
        audio_status: show.audio_status,
        duration_ms: show.duration
      }
    end

    def song_result(song)
      {
        type: "song",
        title: song.title,
        slug: song.slug,
        original: song.original,
        artist: song.artist,
        tracks_count: song.tracks_count
      }
    end

    def venue_result(venue)
      {
        type: "venue",
        name: venue.name,
        slug: venue.slug,
        location: venue.location,
        shows_count: venue.shows_count
      }
    end

    def tag_result(tag)
      {
        type: "tag",
        name: tag.name,
        slug: tag.slug,
        description: tag.description,
        shows_count: tag.shows_count,
        tracks_count: tag.tracks_count
      }
    end

    def playlist_result(playlist)
      {
        type: "playlist",
        name: playlist.name,
        slug: playlist.slug,
        description: playlist.description,
        track_count: playlist.playlist_tracks.size,
        duration_ms: playlist.duration
      }
    end

    def log_mcp_call(result, start_time)
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

      McpToolCall.log_call(
        tool_name: TOOL_NAME,
        parameters: { query: query, limit: limit },
        result: result,
        duration_ms: duration_ms
      )
    end
  end
end
