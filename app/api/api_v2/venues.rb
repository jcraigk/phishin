class ApiV2::Venues < ApiV2::Base
  SORT_COLS = %w[ name shows_count updated_at ]

  resource :venues do
    desc "Fetch a list of venues" do
      detail "Fetch a filtered, sorted, paginated list of venues"
      success ApiV2::Entities::Venue
    end
    params do
      use :pagination, :proximity, :audio_status
      optional :sort,
               type: String,
               desc: "Sort by attribute and direction (e.g., 'name:asc')",
               default: "name:asc",
               values: SORT_COLS.map { |opt| [ "#{opt}:asc", "#{opt}:desc" ] }.flatten
      optional :first_char,
               type: String,
               desc: "Filter venues by the first character of the venue name (case-insensitive)",
               values: App.first_char_list,
               allow_blank: true
    end
    get do
      v = page_of_venues
      present \
        venues: ApiV2::Entities::Venue.represent(v[:venues]),
        total_pages: v[:total_pages],
        current_page: v[:current_page],
        total_entries: v[:total_entries]
    end

    desc "Fetch a venue" do
      detail "Fetch a venue by its slug"
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
        venues = Venue.unscoped
                      .then { |v| apply_proximity_filter(v) }
                      .then { |v| apply_first_char_filter(v) }
                      .then { |v| apply_audio_status_filter(v) }
                      .then { |v| apply_sort(v) }
                      .paginate(page: params[:page], per_page: params[:per_page])

        {
          venues: venues,
          total_pages: venues.total_pages,
          current_page: venues.current_page,
          total_entries: venues.total_entries
        }
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

    def apply_audio_status_filter(venues)
      apply_audio_status_filter_to_venues(venues, params[:audio_status])
    end
  end
end
