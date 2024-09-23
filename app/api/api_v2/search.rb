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
      requires :term,
               type: String,
               desc: "Search term (at least 3 characters long)"
      optional :scope,
               type: String,
               values: %w[all shows songs tags tracks venues],
               default: "all",
               desc: "Specifies the area of the site to search"
    end

    get ":term" do
      return error!({ message: "Term too short" }, 400) if params[:term].length < 3
      results = fetch_results(params[:term], params[:scope])
      all_matched_shows = (Array(results[:exact_show]) + Array(results[:other_shows])).compact
      present \
        results,
        with: ApiV2::Entities::SearchResults,
        liked_track_ids: fetch_liked_track_ids(results[:tracks]),
        liked_show_ids: fetch_liked_show_ids(all_matched_shows)
    end
  end

  helpers do
    def fetch_results(term, scope)
      Rails.cache.fetch("api/v2/search/#{term}/#{scope}") do
        SearchService.new(term, scope).call
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
  end
end
