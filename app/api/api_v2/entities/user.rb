class ApiV2::Entities::User < ApiV2::Entities::Base
  expose \
    :username,
    documentation: {
      type: "String",
      desc: "Username of the user"
    }

  expose \
    :email,
    documentation: {
      type: "String",
      desc: "Email address of the user"
    }

  expose \
    :created_at,
    format_with: :iso8601,
    documentation: {
      type: "String",
      desc: "Timestamp of initial creation"
    }

  expose \
    :username_updated_at,
    format_with: :iso8601,
    documentation: {
      type: "String",
      desc: "Timestamp of when the user's username was last updated"
    }
end
