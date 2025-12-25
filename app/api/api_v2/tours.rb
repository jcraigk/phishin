class ApiV2::Tours < ApiV2::Base
  SORT_COLS = %w[ name starts_on ends_on shows_count updated_at ]

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
      result = page_of_tours
      {
        tours: ApiV2::Entities::Tour.represent(result[:tours]),
        total_pages: result[:total_pages],
        current_page: result[:current_page],
        total_entries: result[:total_entries]
      }
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
      Rails.cache.fetch(cache_key_for_collection("tours")) do
        tours = Tour.unscoped
                    .then { |t| apply_sort(t, :name, :asc) }
                    .then { |t| paginate_relation(t) }

        paginated_response(:tours, tours, tours)
      end
    end

    def tour_by_slug
      Rails.cache.fetch(cache_key_for_resource("tours", params[:slug])) do
        Tour.includes(:shows).find_by!(slug: params[:slug])
      end
    end
  end
end
