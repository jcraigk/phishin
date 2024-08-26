class ApiV2::Songs < ApiV2::Base
  SORT_OPTIONS = [ "title", "tracks_count" ]

  resource :songs do
    desc "Return a list of Songs" do
      detail \
        "Fetches a sortable paginated list of Songs with optional filtering " \
        "by the first character of the title"
      success ApiV2::Entities::Song
      failure [
        [ 400, "Bad Request", ApiV2::Entities::ApiResponse ],
        [ 404, "Not Found", ApiV2::Entities::ApiResponse ]
      ]
    end
    params do
      use :pagination
      optional :sort,
               type: String,
               desc: "Sort by attribute and direction (e.g., 'title:asc')",
               default: "title:asc",
               values: SORT_OPTIONS.map { |option| [ "#{option}:asc", "#{option}:desc" ] }.flatten
      optional :first_char,
               type: String,
               desc: "Filter songs by the first character of the song title (case-insensitive)"
    end
    get do
      present page_of_songs, with: ApiV2::Entities::Song
    end

    desc "Return a specific Song by slug" do
      detail "Fetches a specific Song by its unique slug"
      success ApiV2::Entities::Song
      failure [
        [ 400, "Bad Request", ApiV2::Entities::ApiResponse ],
        [ 404, "Not Found", ApiV2::Entities::ApiResponse ]
      ]
    end
    params do
      requires :slug, type: String, desc: "Slug of the song"
    end
    get ":slug" do
      present song_by_slug, with: ApiV2::Entities::Song
    end
  end

  helpers do
    def page_of_songs
      Rails.cache.fetch("api/v2/songs?#{params.to_query}") do
        Song.unscoped
            .then { |s| apply_filtering(s) }
            .then { |s| apply_sorting(s, SORT_OPTIONS) }
            .paginate(page: params[:page], per_page: params[:per_page])
      end
    end

    def song_by_slug
      Rails.cache.fetch("api/v2/songs/#{params[:slug]}") do
        Song.find_by!(slug: params[:slug])
      end
    end

    def apply_filtering(songs)
      if params[:first_char].present?
        songs = songs.title_starting_with(params[:first_char])
      end
      songs
    end
  end
end
