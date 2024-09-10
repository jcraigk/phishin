class ApiV2::Search < ApiV2::Base
  resource :search do
    desc "Search the database" do
      detail \
        "Performs a search across multiple entities including " \
        "shows, songs, venues, tours, and tags."
      success ApiV2::Entities::SearchResults
      failure [ [ 400, "Bad Request", ApiV2::Entities::ApiResponse ] ]
    end

    params do
      requires :term,
               type: String,
               desc: "Search term (at least 3 characters long)"
      optional :scope,
               type: String,
               values: %w[all shows songs tags tours venues],
               default: "all",
               desc: "Specifies the area of the site to search"
    end

    get ":term" do
      return error!({ message: "Term too short" }, 400) if params[:term].length < 3
      present \
        results(params[:term], params[:scope]),
        with: ApiV2::Entities::SearchResults
    end
  end

  helpers do
    def results(term, scope)
      Rails.cache.fetch("api/v2/search/#{term}/#{scope}") do
        SearchService.new(term, scope).call
      end
    end
  end
end
