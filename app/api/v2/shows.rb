class Api::V2::Shows < Grape::API
  SORT_OPTIONS = [ "date", "likes_count", "duration" ]

  resource :shows do
    desc "Return a list of shows"
    params do
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
      shows = Show.all
      shows = apply_sorting(shows, params[:sort])
      shows = shows.paginate(page: params[:page], per_page: params[:per_page])
      present shows, with: Api::V2::Entities::Show
    end

    desc "Return a specific show by date"
    params do
      requires :date, type: String, desc: "Date of the show"
    end
    get ":date" do
      show = Show.find_by!(date: params[:date])
      present show, with: Api::V2::Entities::Show
    end
  end

  helpers do
    def apply_sorting(shows, sort_param)
      attribute, direction = sort_param.split(":")
      direction ||= "desc"
      if SORT_OPTIONS.include?(attribute) && [ "asc", "desc" ].include?(direction)
        shows.order("#{attribute} #{direction}")
      else
        error!("Invalid sort parameter", 400)
      end
    end
  end
end
