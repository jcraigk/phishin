class GrapeApi::Songs < GrapeApi::Base
  SORT_OPTIONS = [ "title", "tracks_count" ]

  resource :songs do
    desc \
      "Return a list of songs, optionally filtered by the first character " \
      "of the song title, sorted by title or tracks_count"
    params do
      use :pagination
      optional :sort,
               type: String,
               desc: "Sort by attribute and direction (e.g., 'title:asc')",
               default: "title:asc"
      optional :first_char,
               type: String,
               desc: "Filter songs by the first character of the song title (case-insensitive)"
    end
    get do
      present page_of_songs, with: GrapeApi::Entities::Song
    end

    desc "Return a specific Song by slug"
    params do
      requires :slug, type: String, desc: "Slug of the song"
    end
    get ":slug" do
      present song_by_slug, with: GrapeApi::Entities::Song
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