class GrapeApi::Entities::LoginResponse < GrapeApi::Entities::Base
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
