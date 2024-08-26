class GrapeApi::Tours < GrapeApi::Base
  SORT_OPTIONS = [ "name", "starts_on", "ends_on", "shows_count" ]

  resource :tours do
    desc \
      "Return a list of Tours, " \
        "sorted by name, starts_on, ends_on, or shows_count."
    params do
      use :pagination
      optional :sort,
               type: String,
               desc:
               "Sort by attribute and direction (e.g., 'name:asc', " \
                 "'starts_on:desc', etc)",
               default: "starts_on:asc"
    end
    get do
      present page_of_tours, with: GrapeApi::Entities::Tour
    end

    desc "Return a specific Tour by slug, including show details"
    params do
      requires :slug, type: String, desc: "Slug of the tour"
    end
    get ":slug" do
      present tour_by_slug, with: GrapeApi::Entities::Tour, include_shows: true
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
