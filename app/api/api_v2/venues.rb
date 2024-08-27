class ApiV2::Venues < ApiV2::Base
  SORT_OPTIONS = %w[ name shows_count ]

  resource :venues do
    desc "Return a list of venues" do
      detail \
        "Return a sortable paginated list of venues " \
        "optionally filtered by the first character of the venue name and " \
        "by proximity to a specific location"
      success ApiV2::Entities::Venue
    end
    params do
      use :pagination
      optional :sort,
               type: String,
               desc: "Sort by attribute and direction (e.g., 'name:asc')",
               default: "name:asc",
               values: SORT_OPTIONS.map { |option| [ "#{option}:asc", "#{option}:desc" ] }.flatten
      optional :first_char,
               type: String,
               desc: "Filter venues by the first character of the venue name (case-insensitive)"
      optional :lat,
               type: Float,
               desc: "Latitude for proximity search"
      optional :lng,
               type: Float,
               desc: "Longitude for proximity search"
      optional :distance,
               type: Float,
               desc: "Distance (in miles) for proximity search"
    end
    get do
      present page_of_venues, with: ApiV2::Entities::Venue
    end

    desc "Return a venue" do
      detail "Return a venue by its slug"
      success ApiV2::Entities::Venue
    end
    params do
      requires :slug, type: String, desc: "Slug of the venue"
    end
    get ":slug" do
      present venue_by_slug, with: ApiV2::Entities::Venue
    end
  end

  helpers do
    def page_of_venues
      Rails.cache.fetch("api/v2/venues?#{params.to_query}") do
        Venue.unscoped
             .then { |v| apply_proximity_filter(v) }
             .then { |v| apply_first_char_filter(v) }
             .then { |v| apply_sorting(v, SORT_OPTIONS) }
             .paginate(page: params[:page], per_page: params[:per_page])
      end
    end

    def venue_by_slug
      Rails.cache.fetch("api/v2/venues/#{params[:slug]}") do
        Venue.find_by!(slug: params[:slug])
      end
    end

    def apply_first_char_filter(venues)
      if params[:first_char].present?
        venues = venues.name_starting_with(params[:first_char])
      end
      venues
    end

    def apply_proximity_filter(venues)
      if params[:lat].present? && params[:lng].present? && params[:distance].present?
        venues = venues.near([ params[:lat], params[:lng] ], params[:distance])
      end
      venues
    end
  end
end
