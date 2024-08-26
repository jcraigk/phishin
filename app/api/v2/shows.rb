class Api::V2::Shows < Grape::API
  SORT_OPTIONS = [ "date", "likes_count", "duration" ]

  resource :shows do
    desc "Return a list of shows, optionally filtered by year or year range"
    params do
      optional :year,
               type: Integer,
               desc: "Filter shows by a specific year"
      optional :year_range,
               type: String,
               desc: "Filter shows by a range of years (e.g., '1987-1988')"
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
      present page_of_shows, with: Api::V2::Entities::Show
    end

    desc "Return a specific Show by date, including Tracks and Tags"
    params do
      requires :date, type: String, desc: "Date of the show"
    end
    get ":date" do
      present show_by_date, with: Api::V2::Entities::Show, include_tracks: true
    end
  end

  helpers do
    def page_of_shows
      Show.published
          .then { |s| apply_filtering(s) }
          .then { |s| apply_sorting(s) }
          .paginate(page: params[:page], per_page: params[:per_page])
    end

    def show_by_date
      Show.published.find_by!(date: params[:date])
    end

    def apply_filtering(shows)
      if params[:year]
        shows = shows.where("extract(year from date) = ?", params[:year])
      elsif params[:year_range]
        start_year, end_year = params[:year_range].split("-").map(&:to_i)
        shows = shows.where("extract(year from date) BETWEEN ? AND ?", start_year, end_year)
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
