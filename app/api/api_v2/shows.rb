class ApiV2::Shows < ApiV2::Base
  SORT_OPTIONS = %w[ date likes_count duration updated_at ]

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
      use :pagination
      optional :sort,
               type: String,
               desc: "Sort by attribute and direction (e.g., 'date:desc')",
               default: "date:desc",
               values: SORT_OPTIONS.map { |option| [ "#{option}:asc", "#{option}:desc" ] }.flatten
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
      optional :lat,
               type: Float,
               desc: "Latitude to filter shows by proximity to a venue"
      optional :lng,
               type: Float,
               desc: "Longitude to filter shows by proximity to a venue"
      optional :distance,
               type: Float,
               desc: "Distance in miles to filter shows by proximity to a venue"
    end
    get do
      present page_of_shows, with: ApiV2::Entities::Show
    end

    desc "Return a random show" do
      detail "Return a random show"
      success ApiV2::Entities::Show
    end
    get "random" do
      present \
        Show.published.order("RANDOM()").first,
        with: ApiV2::Entities::Show,
        include_tracks: true
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
      present Show.find(params[:id]), with: ApiV2::Entities::Show, include_tracks: true
    end

    desc "Return a show by date" do
      detail "Return a show by its date, including associated tracks and tags"
      success ApiV2::Entities::Show
      failure [
        [ 400, "Bad Request", ApiV2::Entities::ApiResponse ],
        [ 404, "Not Found", ApiV2::Entities::ApiResponse ]
      ]
    end
    get "on_date/:date" do
      present show_by_date, with: ApiV2::Entities::Show, include_tracks: true
    end

    desc "Return shows on a specific day of the year" do
      detail \
        "Return all shows that occurred on a specific day of the year " \
        "based on the provided date"
      success ApiV2::Entities::Show
    end
    get "on_day_of_year/:date" do
      date = Date.parse(params[:date])
      shows =
        Show.published
            .where("extract(month from date) = ?", date.month)
            .where("extract(day from date) = ?", date.day)
      present shows, with: ApiV2::Entities::Show
    rescue ArgumentError
      error!({ message: "Invalid date format" }, 400)
    end
  end

  helpers do
    def page_of_shows
      Rails.cache.fetch("api/v2/shows?#{params.to_query}") do
        Show.published
            .includes(:venue, show_tags: :tag)
            .then { |s| apply_filtering(s) }
            .then { |s| apply_sorting(s, SORT_OPTIONS) }
            .paginate(page: params[:page], per_page: params[:per_page])
      end
    end

    def show_by_date
      Rails.cache.fetch("api/v2/shows/#{params[:date]}") do
        Show.published
            .includes(:venue, tracks: { track_tags: :tag }, show_tags: :tag)
            .find_by!(date: params[:date])
      end
    end

    def apply_filtering(shows)
      if params[:year]
        shows = shows.where("extract(year from date) = ?", params[:year])
      elsif params[:year_range]
        start_year, end_year = params[:year_range].split("-").map(&:to_i)
        shows = shows.where("extract(year from date) BETWEEN ? AND ?", start_year, end_year)
      end

      if params[:venue_slug]
        shows = shows.joins(:venue).where(venues: { slug: params[:venue_slug] })
      end

      if params[:tag_slug]
        shows = shows.joins(:tags).where(tags: { slug: params[:tag_slug] })
      end

      if params[:lat].present? && params[:lng].present? && params[:distance].present?
        venue_ids = Venue.near([ params[:lat], params[:lng] ], params[:distance]).all.map(&:id)
        shows = shows.where(venue_id: venue_ids)
      end

      shows
    end
  end
end
