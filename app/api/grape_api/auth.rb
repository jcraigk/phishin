require "jwt"

class GrapeApi::Auth < GrapeApi::Base
  helpers do
    def authenticate_user!(email, password)
      user = User.find_by(email:)
      if user&.valid_password?(password)
        [ user, jwt_for(user) ]
      else
        error!("Invalid email or password", 401)
      end
    end

    def jwt_for(user)
      JWT.encode(
        {
          sub: user.id,
          exp: (Time.now + 1.year).to_i
        },
        Rails.application.secret_key_base,
        "HS256"
      )
    end

    def current_user
      return unless (token = headers["X-Auth-Token"])
      decoded_token = JWT.decode \
        token,
        Rails.application.secret_key_base,
        true,
        algorithm: "HS256"
      user_id = decoded_token[0]["sub"]
      User.find_by(id: user_id)
    rescue JWT::DecodeError
      nil
    end

    def authenticate!
      error!("Unauthorized", 401) unless current_user
    end
  end

  resource :auth do
    desc "User login via email and password"
    params do
      requires :email, type: String, desc: "User email"
      requires :password, type: String, desc: "User password"
    end
    post :login do
      user, token = authenticate_user!(params[:email], params[:password])
      status 200
      { token:, username: user.username, email: user.email }
    end

    desc "Get currently logged in user"
    get :user do
      authenticate!
      present current_user, with: GrapeApi::Entities::User
    end
  end
end
