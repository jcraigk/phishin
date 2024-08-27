class ApiV2::Entities::Venue < ApiV2::Entities::Base
  expose \
    :slug,
    documentation: {
      type: "String",
      desc: "Unique slug identifier for the venue"
    }

  expose \
    :name,
    documentation: {
      type: "String",
      desc: "Name of the venue"
    }

  expose \
    :other_names,
    documentation: {
      is_array: true,
      desc: "Other names or aliases of the venue"
    }

  expose \
    :latitude,
    documentation: {
      type: "Float",
      desc: "Latitude of the venue"
    }

  expose \
    :longitude,
    documentation: {
      type: "Float",
      desc: "Longitude of the venue"
    }

  expose \
    :city,
    documentation: {
      type: "String",
      desc: "City where the venue is located"
    }

  expose \
    :state,
    documentation: {
      type: "String",
      desc: "State or region where the venue is located"
    }

  expose \
    :country,
    documentation: {
      type: "String",
      desc: "Country where the venue is located"
    }

  expose \
    :location,
    documentation: {
      type: "String",
      desc: "Full location of the venue (city, state, country)"
    }

  expose \
    :shows_count,
    documentation: {
      type: "Integer",
      desc: "Number of shows that have taken place at the venue"
    }

  expose \
    :updated_at,
    format_with: :iso8601,
    documentation: {
      type: "String",
      format: "date-time",
      desc: "Timestamp of the last update to the venue"
    }
end
