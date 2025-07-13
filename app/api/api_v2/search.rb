class ApiV2::Search < ApiV2::Base
  resource :search do
    desc "Search the database" do
      detail \
        "Perform a text based search across " \
        "shows, tracks, songs, venues, and tags."
      success ApiV2::Entities::SearchResults
      failure [ [ 400, "Bad Request", ApiV2::Entities::ApiResponse ] ]
    end

    params do
      use :audio_status
      requires :term,
               type: String,
               desc: "Search term (at least 3 characters long)"
      optional :scope,
               type: String,
               values: SearchService::SCOPES,
               default: "all",
               desc: "Specifies the area of the site to search"
    end

    get ":term" do
      return error!({ message: "Term too short" }, 400) if params[:term].length < 3
      results = fetch_results(params[:term], params[:scope], params[:audio_status])

      # Add Show Tag matches to other_shows
      if results[:show_tags].present?
        ids = results[:show_tags].map(&:show_id) + (results[:other_shows].map(&:id) || [])
        results[:other_shows] = Show.where(id: ids)
      end

      # Add Track Tag matches to tracks
      if results[:track_tags].present?
        ids = results[:track_tags].map(&:track_id) + (results[:tracks]&.map(&:id) || [])
        results[:tracks] = Track.where(id: ids)
      end

      all_matched_shows = (Array(results[:exact_show]) + Array(results[:other_shows])).compact

      present \
        results,
        with: ApiV2::Entities::SearchResults,
        liked_track_ids: fetch_liked_track_ids(results[:tracks]),
        liked_show_ids: fetch_liked_show_ids(all_matched_shows),
        liked_playlists_ids: fetch_liked_playlist_ids(results[:playlists])
    end
  end

  helpers do
    def fetch_results(term, scope, audio_status = "any")
      Rails.cache.fetch("api/v2/search/#{term}/#{scope}/#{audio_status}") do
        SearchService.call(term: term, scope: scope, audio_status: audio_status)
      end
    end

    def fetch_liked_track_ids(tracks)
      return [] unless current_user && tracks
      Like.where(
        likable_type: "Track",
        likable_id: tracks.map(&:id),
        user_id: current_user.id
      ).pluck(:likable_id)
    end

    def fetch_liked_show_ids(shows)
      return [] unless current_user && shows
      Like.where(
        likable_type: "Show",
        likable_id: shows.map(&:id),
        user_id: current_user.id
      ).pluck(:likable_id)
    end

    def fetch_liked_playlist_ids(playlists)
      return [] unless current_user && playlists
      Like.where(
        likable_type: "Playlist",
        likable_id: playlists.map(&:id),
        user_id: current_user.id
      ).pluck(:likable_id)
    end
  end
end
