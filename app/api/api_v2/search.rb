class ApiV2::Search < ApiV2::Base
  resource :search do
    desc "Search all content" do
      detail \
        "Performs a search across multiple entities including " \
        "shows, songs, venues, tours, and tags"
      success ApiV2::Entities::SearchResults
      failure [ [ 400, "Bad Request", ApiV2::Entities::ApiResponse ] ]
    end
    params do
      requires :term,
               type: String,
               desc: "Search term"
    end
    get do
      return error!({ message: "Term too short" }, 400) if params[:term].length < 3
      present \
        SearchService.new(params[:term]).call,
        with: ApiV2::Entities::SearchResults
    end
  end
end
