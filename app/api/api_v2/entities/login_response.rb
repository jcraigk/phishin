class ApiV2::Entities::LoginResponse < ApiV2::Entities::Base
  expose \
    :jwt,
    documentation: {
      type: "String",
      desc: "JWT"
    }

  expose \
    :username,
    documentation: {
      type: "String",
      desc: "User's username"
    }

  expose \
    :email,
    documentation: {
      type: "String",
      desc: "User's email address"
    }
end
