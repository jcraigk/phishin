class ApiV2::Shows < ApiV2::Base
  SORT_COLS = %w[date likes_count duration updated_at]

  resource :shows do
    desc "Return a list of shows" do
      detail \
        "Return a sortable paginated list of shows, " \
        "optionally filtered by year, year range, venue slug, tag slug, or proximity to lat/lng"
      success ApiV2::Entities::Show
      failure [
        [ 400, "Bad Request", ApiV2::Entities::ApiResponse ],
        [ 404, "Not Found", ApiV2::Entities::ApiResponse ]
      ]
    end
    params do
      use :pagination, :proximity
      optional :sort,
               type: String,
               desc: "Sort by attribute and direction (e.g., 'date:desc')",
               default: "date:desc",
               values: SORT_COLS.map { |opt| [ "#{opt}:asc", "#{opt}:desc" ] }.flatten
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
               desc: "Abbreviation of a US state to filter shows by venue location"
      optional :liked_by_user,
               type: Boolean,
               default: false,
               desc: "If true, only return shows liked by the current user"
    end
    get do
      page = page_of_shows
      liked_show_ids = current_user ? fetch_liked_show_ids(page[:shows]) : []
      present \
        shows: ApiV2::Entities::Show.represent(page[:shows], liked_show_ids:),
        total_pages: page[:total_pages],
        current_page: page[:current_page],
        total_entries: page[:total_entries]
    end

    desc "Return a random show" do
      detail "Return a random show"
      success ApiV2::Entities::Show
    end
    get "random" do
      present \
        Show.published.order("RANDOM()").first,
        with: ApiV2::Entities::Show,
        include_tracks: true,
        liked_by_user: current_user ? current_user.likes.exists?(likable: show) : false
    end

    desc "Return a show by id" do
      detail "Return a show by its ID, including associated tracks and tags"
      success ApiV2::Entities::Show
      failure [
        [ 400, "Bad Request", ApiV2::Entities::ApiResponse ],
        [ 404, "Not Found", ApiV2::Entities::ApiResponse ]
      ]
    end
    get ":id" do
      show = Show.find(params[:id])
      present \
        show,
        with: ApiV2::Entities::Show,
        liked_by_user: current_user ? current_user.likes.exists?(likable: show) : false,
        next_show_date: next_show_date(show.date),
        previous_show_date: previous_show_date(show.date)
    end

    desc "Return a show by date" do
      detail "Return a show by its date, including associated tracks and tags"
      success ApiV2::Entities::Show
      failure [
        [ 400, "Bad Request", ApiV2::Entities::ApiResponse ],
        [ 404, "Not Found", ApiV2::Entities::ApiResponse ]
      ]
    end
    params do
      requires :date, type: String, desc: "Date in the format YYYY-MM-DD"
    end
    get "on_date/:date" do
      show = show_by_date
      present \
        show,
        with: ApiV2::Entities::Show,
        include_tracks: true,
        liked_by_user: current_user ? current_user.likes.exists?(likable: show) : false,
        next_show_date: next_show_date(show.date),
        previous_show_date: previous_show_date(show.date)
    end

    desc "Return shows on a specific day of the year" do
      detail \
        "Return all shows that occurred on a specific day of the year " \
        "based on the provided date"
      success ApiV2::Entities::Show
    end
    params do
      requires :date, type: String, desc: "Date in the format YYYY-MM-DD"
    end
    get "on_day_of_year/:date" do
      date = Date.parse(params[:date])
      shows =
        Show.published
            .where("extract(month from date) = ?", date.month)
            .where("extract(day from date) = ?", date.day)
      liked_show_ids = current_user ? fetch_liked_show_ids(shows) : []
      present \
        shows: ApiV2::Entities::Show.represent(shows, liked_show_ids:)
    rescue ArgumentError
      error!({ message: "Invalid date format" }, 400)
    end
  end

  helpers do
    def page_of_shows
      Rails.cache.fetch("api/v2/shows?#{params.to_query}") do
        shows = Show.published
                    .includes(:venue, show_tags: :tag)
                    .then { |s| apply_filter(s) }
                    .then { |s| apply_sort(s) }
                    .paginate(page: params[:page], per_page: params[:per_page])

        {
          shows: shows,
          total_pages: shows.total_pages,
          current_page: shows.current_page,
          total_entries: shows.total_entries
        }
      end
    end

    def fetch_liked_show_ids(shows)
      show_ids = shows.map(&:id)
      Like.where(
        likable_type: "Show",
        likable_id: show_ids,
        user_id: current_user.id
      ).pluck(:likable_id)
    end

    def show_by_date
      Rails.cache.fetch("api/v2/shows/#{params[:date]}") do
        Show.published
            .includes(:venue, tracks: { track_tags: :tag }, show_tags: :tag)
            .find_by!(date: params[:date])
      end
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

      if params[:liked_by_user] && current_user
        liked_show_ids = Like.where(user_id: current_user.id, likable_type: "Show").pluck(:likable_id)
        shows = shows.where(id: liked_show_ids)
      end

      shows
    end

    def apply_sort(shows)
      sort_by, sort_direction = params[:sort].split(":")
      shows.order("#{sort_by} #{sort_direction}")
    end

    def next_show_date(current_date)
      Show.published
          .where("date > ?", current_date)
          .order(date: :asc)
          .pluck(:date).first ||
            Show.published.order(date: :asc).pluck(:date).first
    end

    def previous_show_date(current_date)
      Show.published
          .where("date < ?", current_date)
          .order(date: :desc)
          .pluck(:date).first ||
            Show.published.order(date: :desc).pluck(:date).first
    end
  end
end
