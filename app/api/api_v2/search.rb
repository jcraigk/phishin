class ApiV2::Search < ApiV2::Base
  resource :search do
    desc "Search the database" do
      detail \
        "Performs a search across multiple entities including " \
        "shows, songs, venues, tours, and tags"
      success ApiV2::Entities::SearchResults
      failure [ [ 400, "Bad Request", ApiV2::Entities::ApiResponse ] ]
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
