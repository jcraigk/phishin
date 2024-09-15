class ApiV2::Entities::MissingContentReport < ApiV2::Entities::Base
  expose \
    :missing_show_dates,
    documentation: {
      type: "Array[String]",
      desc: \
        "A list of dates on which Phish is known to have played " \
        "but for which there is no circulated recording. Dates are in ISO 8601 format."
    }

  expose \
    :incomplete_show_dates,
    documentation: {
      type: "Array[String]",
      desc: \
        "A list of dates on which Phish is known to have played " \
        "but for which there is only a partial recording. Dates are in ISO 8601 format."
    }
end
