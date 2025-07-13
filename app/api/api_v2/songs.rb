class ApiV2::Songs < ApiV2::Base
  SORT_COLS = %w[ title tracks_count updated_at ]

  resource :songs do
    desc "Fetch a list of songs" do
      detail "Fetch a filtered, sorted, paginated list of songs"
      success ApiV2::Entities::Song
      failure [
        [ 400, "Bad Request", ApiV2::Entities::ApiResponse ],
        [ 404, "Not Found", ApiV2::Entities::ApiResponse ]
      ]
    end
    params do
      use :pagination, :audio_status
      optional :sort,
               type: String,
               desc: "Sort by attribute and direction (e.g., 'title:asc')",
               default: "title:asc",
               values: SORT_COLS.map { |opt| [ "#{opt}:asc", "#{opt}:desc" ] }.flatten
      optional :first_char,
               type: String,
               desc: "Filter songs by the first character of the song title (case-insensitive)",
               values: App.first_char_list
    end
    get do
      s = page_of_songs
      present \
        songs: ApiV2::Entities::Song.represent(s[:songs]),
        total_pages: s[:total_pages],
        current_page: s[:current_page],
        total_entries: s[:total_entries]
    end

    desc "Fetch a song" do
      detail "Fetch a song by its slug"
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
        songs = Song.unscoped
                    .then { |s| apply_filter(s) }
                    .then { |s| apply_audio_status_filter(s) }
                    .then { |s| apply_sort(s, :title, :asc) }
                    .paginate(page: params[:page], per_page: params[:per_page])

        {
          songs: songs,
          total_pages: songs.total_pages,
          current_page: songs.current_page,
          total_entries: songs.total_entries
        }
      end
    end

    def song_by_slug
      Rails.cache.fetch("api/v2/songs/#{params[:slug]}") do
        Song.find_by!(slug: params[:slug])
      end
    end

    def apply_filter(songs)
      if params[:first_char].present?
        songs = songs.title_starting_with(params[:first_char])
      end
      songs
    end

    def apply_audio_status_filter(songs)
      apply_audio_status_filter_to_songs(songs, params[:audio_status])
    end
  end
end
