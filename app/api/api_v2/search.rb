class ApiV2::Search < ApiV2::Base
  resource :search do
    params do
      requires :date, type: String, desc: "Date of the show in the format YYYY-MM-DD"
    end
    desc "Search the database" do
      detail \
        "Performs a search across multiple entities including " \
        "shows, songs, venues, tours, and tags"
      success ApiV2::Entities::SearchResults
      failure [ [ 400, "Bad Request", ApiV2::Entities::ApiResponse ] ]
    end
    params do
      requires :term, type: String, desc: "Search term (at least 3 characters long)"
    end
    get ":term" do
      return error!({ message: "Term too short" }, 400) if params[:term].length < 3
      present search_results, with: ApiV2::Entities::SearchResults
    end
  end

  helpers do
    def search_results
      Rails.cache.fetch("api/v2/search/#{params[:term]}") do
        SearchService.new(params[:term]).call
      end
    end
  end
end
