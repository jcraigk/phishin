module ApiV2::Helpers::SharedParams
  extend Grape::API::Helpers

  params :pagination do
    optional :page,
            type: Integer,
            desc: "Page number for pagination",
            default: 1,
            values: 1..100_000
    optional :per_page,
            type: Integer,
            desc: "Number of items per page for pagination",
            default: 10,
            values: 1..1_000
  end

  params :proximity do
    optional :lat,
      type: Float,
      desc: "Latitude for proximity search",
      values: -90.0..90.0
    optional :lng,
      type: Float,
      desc: "Longitude for proximity search",
      values: -180.0..180.0
    optional :distance,
      type: Float,
      desc: "Distance (in miles) for proximity search",
      values: 0.0..12450.0
  end
end
