class ApiV2::Tours < ApiV2::Base
  SORT_OPTIONS = [ "name", "starts_on", "ends_on", "shows_count" ]

  resource :tours do
    desc "Return a list of Tours" do
      detail "Fetches a sortable paginated list of Tours"
      success ApiV2::Entities::Tour
    end
    params do
      use :pagination
      optional :sort,
               type: String,
               desc: "Sort by attribute and direction (e.g., 'starts_on:asc')",
               default: "starts_on:asc",
               values: SORT_OPTIONS.map { |option| [ "#{option}:asc", "#{option}:desc" ] }.flatten
    end
    get do
      present page_of_tours, with: ApiV2::Entities::Tour
    end

    desc "Return a specific Tour by slug" do
      detail "Fetches a specific Tour by its slug, including details of associated shows"
      success ApiV2::Entities::Tour
    end
    params do
      requires :slug, type: String, desc: "Slug of the tour"
    end
    get ":slug" do
      present tour_by_slug, with: ApiV2::Entities::Tour, include_shows: true
    end
  end

  helpers do
    def page_of_tours
      Rails.cache.fetch("api/v2/tours?#{params.to_query}") do
        Tour.unscoped
            .then { |t| apply_sorting(t, SORT_OPTIONS) }
            .paginate(page: params[:page], per_page: params[:per_page])
      end
    end

    def tour_by_slug
      Rails.cache.fetch("api/v2/tours/#{params[:slug]}") do
        Tour.includes(:shows).find_by!(slug: params[:slug])
      end
    end
  end
end
