module ApiV2::Helpers::SharedParams
  extend Grape::API::Helpers

  params :audio_status do
    optional :audio_status,
             type: String,
             desc: "Filter by audio status: 'any' (default), 'complete', 'partial', 'missing', 'complete_or_partial'",
             default: "any",
             values: %w[any complete partial missing complete_or_partial].freeze
  end

  params :pagination do
    optional :page,
            type: Integer,
            desc: "Page number for pagination (min: 1)",
            default: 1
    optional :per_page,
            type: Integer,
            desc: "Number of items per page for pagination (min: 1, max: 1000)",
            default: 10
  end

  params :trim_params do
    optional :trim_start, type: Float, default: 0.0
    requires :trim_end, type: Float
    optional :fade_in, type: Float, default: 0.2
    optional :fade_out, type: Float, default: 6.0
  end

  # Titles are optional on both boundary endpoints: a shift can rename the two
  # tracks it touches, and a side left out keeps the title it has.
  params :shift_boundary_params do
    requires :delta_s, type: Float
    optional :titles, type: Hash do
      optional :first, type: String
      optional :second, type: String
    end
  end

  params :proximity do
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
end
