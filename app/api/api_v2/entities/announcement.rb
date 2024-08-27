class ApiV2::Entities::Announcement < ApiV2::Entities::Base
  expose \
    :title,
    documentation: {
      type: "String",
      desc: "Title of the announcement"
    }

  expose \
    :description,
    documentation: {
      type: "String",
      desc: "Description of the announcement"
    }

  expose \
    :url,
    documentation: {
      type: "String",
      desc: "URL related to the announcement (usually a Show)"
    }

  expose \
    :created_at,
    format_with: :iso8601,
    documentation: {
      type: "String",
      desc: "Timestamp when the announcement was created"
    }
end
