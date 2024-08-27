module ApiHelper
  def auth_header
    api_key = create(:api_key)
    { "Authorization" => "Bearer #{api_key.key}" }
  end

  def user_auth_header(user)
    token = JWT.encode(
      {
        sub: user.id,
        exp: (Time.now + 1.year).to_i
      },
      Rails.application.secret_key_base,
      "HS256"
    )
    { "X-Auth-Token" => token }
  end

  %i[ get post put delete ].each do |http_method|
    define_method("#{http_method}_api") do |path, params: {}, headers: {}, version: 2|
      # headers.merge!(auth_header)
      send(http_method, "/api/v#{version}#{path}", params:, headers:)
    end

    define_method("#{http_method}_api_authed") do |user, path, params: {}, headers: {}, version: 2|
      headers.merge!(user_auth_header(user))
      send("#{http_method}_api", path, params:, headers:, version:)
    end
  end
end
