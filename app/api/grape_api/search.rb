class GrapeApi::Search < GrapeApi::Base
  resource :search do
    desc "Search across Shows, Songs, Venues, Tours, and Tags"
    params do
      requires :term, type: String, desc: "Search term"
    end
    get do
      results = SearchService.new(params[:term]).call
      if results
        present results, with: GrapeApi::Entities::SearchResults
      else
        error!("No results found or search term too short", 404)
      end
    end
  end
end
