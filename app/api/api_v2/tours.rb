class ApiV2::Tours < ApiV2::Base
  SORT_COLS = %w[ name starts_on ends_on shows_count ]

  resource :tours do
    desc "Fetch a list of tours" do
      detail "Fetch a sorted, paginated list of tours"
      success ApiV2::Entities::Tour
    end
    params do
      use :pagination
      optional :sort,
               type: String,
               desc: "Sort by attribute and direction (e.g., 'starts_on:asc')",
               default: "starts_on:asc",
               values: SORT_COLS.map { |opt| [ "#{opt}:asc", "#{opt}:desc" ] }.flatten
    end
    get do
      present page_of_tours, with: ApiV2::Entities::Tour
    end

    desc "Fetch a tour" do
      detail "Fetch a tour by its slug, including associated shows"
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
            .then { |t| apply_sort(t) }
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
