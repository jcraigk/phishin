class ApiV2::Entities::MissingContentReport < ApiV2::Entities::Base
  expose \
    :missing_shows,
    documentation: {
      type: "Array[Object]",
      desc: \
        "A list of shows for which there is no circulated recording. " \
        "Each object contains the date, venue_name, and location."
    }

  expose \
    :incomplete_shows,
    documentation: {
      type: "Array[Object]",
      desc: \
        "A list of shows for which there is only a partial recording. " \
        "Each object contains the date, venue_name, and location."
    }
end
