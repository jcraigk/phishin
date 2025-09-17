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
