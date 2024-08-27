class ApiV2::Tracks < ApiV2::Base
  SORT_OPTIONS = %w[ id title likes_count duration ]

  resource :tracks do
    desc "Return a list of tracks" do
      detail \
        "Fetches a sortable paginated list of tracks, " \
        "optionally filtered by tag_slug."
      success ApiV2::Entities::Track
      failure [
        [ 400, "Bad Request", ApiV2::Entities::ApiResponse ],
        [ 404, "Not Found", ApiV2::Entities::ApiResponse ]
      ]
    end
    params do
      use :pagination
      optional :sort,
               type: String,
               desc: "Sort by attribute and direction (e.g., 'id:asc')",
               default: "id:asc",
               values: SORT_OPTIONS.map { |option| [ "#{option}:asc", "#{option}:desc" ] }.flatten
      optional :tag_slug,
               type: String,
               desc: "Filter tracks by the slug of the tag"
    end
    get do
      present page_of_tracks, with: ApiV2::Entities::Track, show_details: true
    end

    desc "Return a specific track by ID" do
      detail "Fetches a specific track by its ID, including show details, tags, and songs"
      success ApiV2::Entities::Track
      failure [
        [ 400, "Bad Request", ApiV2::Entities::ApiResponse ],
        [ 404, "Not Found", ApiV2::Entities::ApiResponse ]
      ]
    end
    params do
      requires :id, type: Integer, desc: "ID of the track"
    end
    get ":id" do
      present track_by_id, with: ApiV2::Entities::Track, show_details: true
    end
  end

  helpers do
    def page_of_tracks
      Rails.cache.fetch("api/v2/tracks?#{params.to_query}") do
        Track.includes(:show, :songs, track_tags: :tag)
             .then { |t| apply_filtering(t) }
             .then { |t| apply_sorting(t, SORT_OPTIONS) }
             .paginate(page: params[:page], per_page: params[:per_page])
      end
    end

    def track_by_id
      Rails.cache.fetch("api/v2/tracks/#{params[:id]}") do
        Track.includes(:show, :songs, track_tags: :tag).find_by!(id: params[:id])
      end
    end

    def apply_filtering(tracks)
      if params[:tag_slug]
        tracks = tracks.joins(track_tags: :tag).where(tags: { slug: params[:tag_slug] })
      end
      tracks
    end
  end
end
