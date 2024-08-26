class GrapeApi::Search < GrapeApi::Base
  resource :search do
    desc "Search all content" do
      detail \
        "Performs a search across multiple entities including " \
        "Shows, Songs, Venues, Tours, and Tags."
      success GrapeApi::Entities::SearchResults
      failure [ [ 400, "Bad Request", GrapeApi::Entities::ApiResponse ] ]
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
        with: GrapeApi::Entities::SearchResults
    end
  end
end
