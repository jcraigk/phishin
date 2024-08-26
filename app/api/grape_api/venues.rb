class GrapeApi::Venues < GrapeApi::Base
  SORT_OPTIONS = [ "name", "shows_count" ]

  resource :venues do
    desc \
      "Return a list of venues, " \
        "optionally filtered by the first character of the venue name, " \
        "sorted by name or shows_count."
    params do
      use :pagination
      optional :sort,
               type: String,
               desc:
               "Sort by attribute and direction (e.g., 'name:asc', " \
                 "'shows_count:desc')",
              default: "name:asc"
      optional :first_char,
               type: String,
               desc: "Filter venues by the first character of the venue name (case-insensitive)"
    end
    get do
      present page_of_venues, with: GrapeApi::Entities::Venue
    end

    desc "Return a specific Venue by slug"
    params do
      requires :slug, type: String, desc: "Slug of the venue"
    end
    get ":slug" do
      present venue_by_slug, with: GrapeApi::Entities::Venue
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
