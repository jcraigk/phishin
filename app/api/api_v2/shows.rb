class ApiV2::Shows < ApiV2::Base # rubocop:disable Metrics/ClassLength
  SORT_COLS = %w[ date likes_count duration updated_at ]

  helpers do
    params :sort do
      optional :sort,
               type: String,
               desc: "Sort by attribute and direction (e.g., 'date:desc')",
               default: "date:desc",
               values: SORT_COLS.map { |opt| [ "#{opt}:asc", "#{opt}:desc" ] }.flatten
    end
  end

  resource :shows do
    desc "Fetch a list of shows" do
      detail "Fetch a filtered, sorted, paginated list of shows"
      success ApiV2::Entities::Show
      failure [
        [ 400, "Bad Request", ApiV2::Entities::ApiResponse ],
        [ 404, "Not Found", ApiV2::Entities::ApiResponse ]
      ]
    end
    params do
      use :pagination, :proximity, :sort, :audio_status
      optional :year,
               type: Integer,
               desc: "Filter shows by a specific year"
      optional :year_range,
               type: String,
               desc: "Filter shows by a range of years (e.g., '1987-1988')"
      optional :venue_slug,
               type: String,
               desc: "Filter shows by the slug of the venue"
      optional :tag_slug,
               type: String,
               desc: "Filter shows by the slug of an associated tag"
      optional :start_date,
               type: String,
               desc: "Filter shows from this start date (inclusive)",
               default: "1970-01-01"
      optional :end_date,
               type: String,
               desc: "Filter shows up to this end date (inclusive)",
               default: "2070-01-01"
      optional :us_state,
               type: String,
               desc: "Filter shows by US state (abbreviations)"
      optional :liked_by_user,
               type: Boolean,
               default: false,
               desc: "If true, fetch only those shows liked by the current user"
    end
    get do
      page = page_of_shows
      liked_show_ids = fetch_liked_show_ids(page[:shows])
      {
        shows: ApiV2::Entities::Show.represent(page[:shows], liked_show_ids:, exclude_tracks: true),
        total_pages: page[:total_pages],
        current_page: page[:current_page],
        total_entries: page[:total_entries]
      }
    end

    desc "Fetch a random show" do
      detail "Fetch a random show"
      success ApiV2::Entities::Show
    end
    get "random" do
      show = Show.with_audio.order("RANDOM()").first
      present \
        show,
        with: ApiV2::Entities::Show,
        liked_by_user: current_user&.likes&.exists?(likable: show) || false,
        liked_track_ids: fetch_liked_track_ids(show)
    end

    desc "Fetch a show by date" do
      detail "Fetch a specific show by its date, including associated tracks and tags"
      success ApiV2::Entities::Show
      failure [
        [ 400, "Bad Request", ApiV2::Entities::ApiResponse ],
        [ 404, "Not Found", ApiV2::Entities::ApiResponse ]
      ]
    end
    params do
      use :audio_status
      requires :date, type: String, desc: "Date in the format YYYY-MM-DD"
    end
    get ":date" do
      show = show_by_date
      present \
        show,
        with: ApiV2::Entities::Show,
        include_gaps: true,
        liked_by_user: current_user&.likes&.exists?(likable: show) || false,
        liked_track_ids: fetch_liked_track_ids(show),
        next_show_date: show.next_show_date || Show.first_show_date,
        previous_show_date: show.previous_show_date || Show.last_show_date,
        next_show_date_with_audio: show.next_show_date(audio_status: "complete_or_partial") || Show.first_show_date(audio_status: "complete_or_partial"),
        previous_show_date_with_audio: show.previous_show_date(audio_status: "complete_or_partial") || Show.last_show_date(audio_status: "complete_or_partial")
    end

    desc "Fetch shows played on a day of the year" do
      detail \
        "Fetch all shows that occurred on a specific day of the year " \
        "based on the specified date"
      success ApiV2::Entities::Show
    end
    params do
      use :sort, :audio_status
      requires :date, type: String, desc: "Date in the format YYYY-MM-DD"
    end
    get "day_of_year/:date" do
      date = Date.parse(params[:date])
      shows = Show.includes(
                    { venue: :venue_renames },
                    :tour,
                    :cover_art_attachment,
                    :album_cover_attachment,
                    :album_zip_attachment,
                    {
                      tracks: [
                        :mp3_audio_attachment,
                        :png_waveform_attachment,
                        { track_tags: :tag },
                        :songs,
                        :songs_tracks
                      ]
                    },
                    { show_tags: :tag }
                  )
                  .on_day_of_year(date.month, date.day)
      shows = apply_audio_status_filter(shows, params[:audio_status])
      shows = apply_sort(shows, :date, :desc)
      liked_show_ids = fetch_liked_show_ids(shows)
      { shows: ApiV2::Entities::Show.represent(shows, liked_show_ids:) }
    rescue ArgumentError
      error!({ message: "Invalid date format" }, 400)
    end

    desc "Request a ZIP archive of a show's tracks" do
      detail "Request a ZIP archive of a show's tracks, cover art, and taper notes"
      success code: 204, message: "Download requested successfully"
      success code: 409, message: "Download already requested"
    end
    params do
      requires :date, type: String, desc: "Date in the format YYYY-MM-DD"
    end
    post "request_album_zip" do
      show = Show.find_by!(date: params[:date])
      if show.album_zip.attached?
        error!({ message: "Album already generated" }, 409)
      elsif show.album_zip_requested_at.present?
        error!({ message: "Download already requested" }, 409)
      elsif show.missing_audio?
        error!({ message: "Cannot generate album for show with missing audio" }, 400)
      else
        show.update!(album_zip_requested_at: Time.current)
        AlbumZipJob.perform_async(show.id)
        status 204
      end
    end
  end

  helpers do
    def page_of_shows
      shows =
        if params[:liked_by_user] && current_user
          fetch_shows
        else
          Rails.cache.fetch(cache_key_for_collection("shows")) { fetch_shows }
        end

      paginated_response(:shows, shows, shows)
    end

    def fetch_shows
      Show.includes(
            :venue,
            :tour,
            :album_cover_attachment,
            :album_zip_attachment,
            :cover_art_attachment,
            show_tags: :tag
          )
          .then { |s| apply_filter(s) }
          .then { |s| apply_sort(s, :date, :desc) }
          .then { |s| paginate_relation(s) }
    end



    def show_by_date
      if params[:liked_by_user] && current_user
        fetch_show_by_date
      else
        Rails.cache.fetch(cache_key_for_resource("shows", params[:date])) { fetch_show_by_date }
      end
    end

    def fetch_liked_track_ids(show)
      return [] unless current_user && show
      fetch_liked_ids("Track", show.tracks)
    end

    def fetch_show_by_date
      Show.includes(
            :venue,
            { cover_art_attachment: { blob: { variant_records: { image_attachment: :blob } } } },
            tracks: [
              :mp3_audio_attachment,
              :png_waveform_attachment,
              { track_tags: :tag },
              :songs,
              :songs_tracks
            ],
            show_tags: :tag
          )
          .find_by!(date: params[:date])
    end

    def apply_filter(shows)
      if params[:year]
        shows = shows.where("extract(year from date) = ?", params[:year])
      elsif params[:year_range]
        start_year, end_year = params[:year_range].split("-").map(&:to_i)
        shows = shows.where("extract(year from date) BETWEEN ? AND ?", start_year, end_year)
      else
        start_date = Date.parse(params[:start_date])
        end_date = Date.parse(params[:end_date])
        shows = shows.where(date: start_date..end_date)
      end

      if params[:venue_slug]
        venue_ids = Venue.where(slug: params[:venue_slug]).pluck(:id)
        shows = shows.where(venue_id: venue_ids)
      end

      if params[:us_state].present?
        venue_ids = Venue.where(state: params[:us_state]).pluck(:id)
        shows = shows.where(venue_id: venue_ids)
      elsif params[:lat].present? && params[:lng].present? && params[:distance].present?
        venue_ids = Venue.near([ params[:lat], params[:lng] ], params[:distance]).all.map(&:id)
        shows = shows.where(venue_id: venue_ids)
      end

      if params[:tag_slug]
        show_ids = Show.joins(:tags)
                       .where(tags: { slug: params[:tag_slug] })
                       .pluck(:id)
        shows = shows.where(id: show_ids)
      end

      if params[:liked_by_user]
        if current_user
          liked_show_ids = Like.where(
            user_id: current_user.id,
            likable_type: "Show"
          ).pluck(:likable_id)
          shows = shows.where(id: liked_show_ids)
        else
          shows = shows.none
        end
      end

      shows = apply_audio_status_filter(shows, params[:audio_status])

      shows
    end
  end
end
