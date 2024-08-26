class GrapeApi::Shows < Grape::API
  SORT_OPTIONS = [ "date", "likes_count", "duration" ]

  resource :shows do
    desc \
      "Return a list of shows, optionally filtered by year, year range, or venue slug, " \
        "sorted in descending chronological order"
    params do
      optional :year,
               type: Integer,
               desc: "Filter shows by a specific year"
      optional :year_range,
               type: String,
               desc: "Filter shows by a range of years (e.g., '1987-1988')"
      optional :venue_slug,
               type: String,
               desc: "Filter shows by the slug of the venue"
      optional :sort,
               type: String,
               desc: "Sort by attribute and direction (e.g., 'date:desc', 'likes_count:desc')",
               default: "date:desc"
      optional :page,
               type: Integer,
               desc: "Page number for pagination",
               default: 1
      optional :per_page,
               type: Integer,
               desc: "Number of items per page for pagination",
               default: 10
    end
    get do
      present page_of_shows, with: GrapeApi::Entities::Show
    end

    desc "Return a specific Show by date, including Tracks and Tags"
    params do
      requires :date, type: String, desc: "Date of the show"
    end
    get ":date" do
      present show_by_date, with: GrapeApi::Entities::Show, include_tracks: true
    end
  end

  helpers do
    def page_of_shows
      Rails.cache.fetch("api/v2/shows?#{params.to_query}") do
        Show.published
            .includes(:venue, show_tags: :tag)
            .then { |s| apply_filtering(s) }
            .then { |s| apply_sorting(s) }
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

      shows
    end

    def apply_sorting(shows)
      attribute, direction = params[:sort].split(":")
      direction ||= "desc"
      if SORT_OPTIONS.include?(attribute) && [ "asc", "desc" ].include?(direction)
        shows.order("#{attribute} #{direction}")
      else
        error!("Invalid sort parameter", 400)
      end
    end
  end
end
