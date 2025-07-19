class ApiV2::Entities::Tour < ApiV2::Entities::Base
  include ApiV2::Concerns::CountFieldsWithAudio

  expose \
    :slug,
    documentation: {
      type: "String",
      desc: "Unique slug identifier for the tour"
    }

  expose \
    :name,
    documentation: {
      type: "String",
      desc: "Name of the tour"
    }

  expose_count_fields_with_audio :shows_count, "shows associated with the tour"

  expose \
    :starts_on,
    format_with: :iso8601,
    documentation: {
      type: "String",
      format: "date",
      desc: "Start date of the tour"
    }

  expose \
    :ends_on,
    format_with: :iso8601,
    documentation: {
      type: "String",
      format: "date",
      desc: "End date of the tour"
    }

  expose \
    :created_at,
    format_with: :iso8601,
    documentation: {
      type: "String",
      desc: "Timestamp of initial creation"
    }

  expose \
    :updated_at,
    format_with: :iso8601,
    documentation: {
      type: "String",
      desc: "Timestamp of most recent update"
    }

  expose \
    :shows,
    using: ApiV2::Entities::Show,
    if: ->(_, opts) { opts[:include_shows] },
    documentation: {
      type: "Array",
      desc: "List of shows associated with the tour, included only on individual tour requests"
    }
end
