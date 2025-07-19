class ApiV2::Tracks < ApiV2::Base
  SORT_COLS = %w[ id title likes_count duration date updated_at ]

  resource :tracks do
    desc "Fetch a list of tracks" do
      detail "Fetch a filtered, sorted, paginated list of tracks"
      success ApiV2::Entities::Track
      failure [
        [ 400, "Bad Request", ApiV2::Entities::ApiResponse ],
        [ 404, "Not Found", ApiV2::Entities::ApiResponse ]
      ]
    end
    params do
      use :pagination, :audio_status
      optional :sort,
               type: String,
               desc: "Sort by attribute and direction (e.g., 'id:asc')",
               default: "id:asc",
               values: SORT_COLS.map { |opt| [ "#{opt}:asc", "#{opt}:desc" ] }.flatten
      optional :tag_slug,
               type: String,
               desc: "Filter tracks by the slug of the tag"
      optional :song_slug,
               type: String,
               desc: "Filter tracks by the slug of the song"
      optional :liked_by_user,
               type: Boolean,
               desc: "Filter by tracks liked by the current user",
               default: false
      optional :start_date,
               type: String,
               desc: "Filter tracks from shows starting from this date (inclusive)"
      optional :end_date,
               type: String,
               desc: "Filter tracks from shows up to this date (inclusive)"
      optional :year,
               type: Integer,
               desc: "Filter tracks from shows in a specific year"
      optional :year_range,
               type: String,
               desc: "Filter tracks from shows in a range of years (e.g., '1987-1988')"
    end
    get do
      result = page_of_tracks
      liked_track_ids = fetch_liked_track_ids(result[:tracks])
      present \
        tracks: ApiV2::Entities::Track.represent(
          result[:tracks],
          liked_track_ids:,
          include_gaps: true,
          exclude_tracks: true
        ),
        total_pages: result[:total_pages],
        current_page: result[:current_page],
        total_entries: result[:total_entries]
    end

    desc "Fetch a track by ID" do
      detail "Fetch a track by its ID, including show details, tags, and songs"
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
      track = track_by_id
      present \
        track,
        with: ApiV2::Entities::Track,
        liked_by_user: current_user&.likes&.exists?(likable: track) || false,
        include_gaps: true
    end
  end

  helpers do
    def page_of_tracks
      tracks =
        if params[:liked_by_user] && current_user
          fetch_tracks
        else
          Rails.cache.fetch(cache_key_for_collection("tracks")) { fetch_tracks }
        end

      paginated_response(:tracks, tracks, tracks)
    end

    def fetch_tracks
      Track.includes(
              :mp3_audio_attachment,
              :png_waveform_attachment,
              {
                show: %i[
                  album_cover_attachment
                  album_zip_attachment
                  cover_art_attachment
                  tour
                  venue
                  show_tags
                ]
              },
              :songs,
              { track_tags: :tag },
              :songs_tracks
            )
           .then { |t| apply_filter(t) }
           .then { |t| apply_track_sort(t) }
           .then { |t| paginate_relation(t) }
    end

    def track_by_id
      if params[:liked_by_user] && current_user
        fetch_track_by_id
      else
        Rails.cache.fetch(cache_key_for_resource("tracks", params[:id])) { fetch_track_by_id }
      end
    end

    def fetch_track_by_id
      Track.includes(
        :show,
        :songs,
        { track_tags: :tag },
        :songs_tracks
      ).find_by!(id: params[:id])
    end



    def apply_filter(tracks)
      if params[:year].present? && params[:year_range].present?
        error!({ message: "Cannot specify both year and year_range" }, 400)
      end

      if (params[:year].present? || params[:year_range].present?) &&
         (params[:start_date].present? || params[:end_date].present?)
        error!({ message: "Cannot combine year/year_range with start_date/end_date" }, 400)
      end

      if params[:tag_slug]
        track_ids = Track.joins(track_tags: :tag)
                         .where(tags: { slug: params[:tag_slug] })
                         .pluck(:id)
        tracks = tracks.where(id: track_ids)
      end

      if params[:song_slug]
        track_ids = Track.joins(:songs)
                         .where(songs: { slug: params[:song_slug] })
                         .pluck(:id)
        tracks = tracks.where(id: track_ids)
      end

      if params[:liked_by_user]
        if current_user
          liked_track_ids = current_user.likes.where(likable_type: "Track").pluck(:likable_id)
          tracks = tracks.where(id: liked_track_ids)
        else
          tracks = tracks.none
        end
      end

      if params[:year]
        tracks = tracks.joins(:show).where("extract(year from shows.date) = ?", params[:year])
      elsif params[:year_range]
        start_year, end_year = params[:year_range].split("-").map(&:to_i)
        tracks = tracks.joins(:show).where("extract(year from shows.date) BETWEEN ? AND ?", start_year, end_year)
      else
        if params[:start_date].present? && params[:end_date].present?
          start_date = Date.parse(params[:start_date])
          end_date = Date.parse(params[:end_date])
          tracks = tracks.joins(:show).where(shows: { date: start_date..end_date })
        elsif params[:start_date].present?
          start_date = Date.parse(params[:start_date])
          tracks = tracks.joins(:show).where("shows.date >= ?", start_date)
        elsif params[:end_date].present?
          end_date = Date.parse(params[:end_date])
          tracks = tracks.joins(:show).where("shows.date <= ?", end_date)
        end
      end

      tracks = apply_audio_status_filter(tracks, params[:audio_status])

      tracks
    end

    def apply_track_sort(tracks)
      sort_by, sort_direction = params[:sort].split(":")

      case sort_by
      when "date"
        tracks = tracks.joins(:show)
                       .order("shows.date #{sort_direction}")
                       .order("tracks.position asc")
      else
        tracks = tracks.order("#{sort_by} #{sort_direction}")
        tracks = tracks.order("title asc") if sort_by != "title"
      end

      tracks
    end
  end
end
