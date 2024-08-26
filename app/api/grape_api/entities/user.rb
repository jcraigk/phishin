class GrapeApi::Entities::User < GrapeApi::Entities::Base
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
      format: "date-time",
      desc: "Timestamp of when the user was created"
    }
end
