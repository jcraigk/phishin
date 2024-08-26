class ApiV2::Venues < ApiV2::Base
  SORT_OPTIONS = [ "name", "shows_count" ]

  resource :venues do
    desc "Return a list of venues" do
      detail \
        "Return a sortable paginated list of venues " \
        "optionally filtered by the first character of the venue name"
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
    end
    get do
      present page_of_venues, with: ApiV2::Entities::Venue
    end

    desc "Return a specific venue" do
      detail "Return a specific venue by its slug"
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
             .then { |v| apply_filtering(v) }
             .then { |v| apply_sorting(v, SORT_OPTIONS) }
             .paginate(page: params[:page], per_page: params[:per_page])
      end
    end

    def venue_by_slug
      Rails.cache.fetch("api/v2/venues/#{params[:slug]}") do
        Venue.find_by!(slug: params[:slug])
      end
    end

    def apply_filtering(venues)
      if params[:first_char].present?
        venues = venues.name_starting_with(params[:first_char])
      end
      venues
    end
  end
end
