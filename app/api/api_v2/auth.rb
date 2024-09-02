require "jwt"

class ApiV2::Auth < ApiV2::Base
  resource :auth do
    desc "Create a new user" do
      detail \
        "Create a new user with the provided username, email, " \
        "password, and password confirmation"
      success [
        {
          code: 201,
          model: ApiV2::Entities::LoginResponse,
          message: "Create a new user and return a JWT for X-Auth-Token header"
        }
      ]
      failure [
        [ 422, "Unprocessable Entity - User creation failed" ],
        [ 409, "Conflict - Email already exists" ]
      ]
    end
    params do
      requires :username, type: String, desc: "Username"
      requires :email, type: String, desc: "Email"
      requires :password, type: String, desc: "Password"
      requires :password_confirmation, type: String, desc: "Password confirmation"
    end
    post :create_user do
      if User.exists?(email: params[:email])
        error!({ message: "Email already exists" }, 409)
      end

      unless params[:password] == params[:password_confirmation]
        error!({ message: "Passwords do not match" }, 422)
      end

      user = User.new \
        username: params[:username],
        email: params[:email],
        password: params[:password]

      if user.save
        status 201
        present(
          { jwt: jwt_for(user), username: user.username, email: user.email },
          with: ApiV2::Entities::LoginResponse
        )
      else
        error!({ message: user.errors.full_messages.join(", ") }, 422)
      end
    end

    desc "User login via email and password" do
      detail \
        "Authenticate a user using their email and password " \
        "and return a JWT for X-Auth-Token header"
      success [ { code: 200, model: ApiV2::Entities::LoginResponse } ]
      failure [ [ 401, "Unauthorized - Invalid email or password" ] ]
    end
    params do
      requires :email, type: String, desc: "User email"
      requires :password, type: String, desc: "User password"
    end
    post :login do
      user, jwt = authenticate_user!(params[:email], params[:password])
      status 200
      present(
        { jwt:, username: user.username, email: user.email },
        with: ApiV2::Entities::LoginResponse
      )
    end

    desc "Get currently logged in user" do
      detail "Return the currently authenticated User"
      success ApiV2::Entities::User
      failure [ [ 401, "Unauthorized - Invalid JWT" ] ]
    end
    get :user do
      authenticate!
      present current_user, with: ApiV2::Entities::User
    end

    desc "Request password reset email" do
      detail "Send a password reset email to the user if found"
      success [ { code: 200, model: ApiV2::Entities::ApiResponse } ]
    end
    params do
      requires :email, type: String, desc: "User email"
    end
    post :request_password_reset do
      user = User.find_by(email: params[:email])
      user&.deliver_reset_password_instructions!
      status 200
      { message: "Password reset instructions will be sent to the email if it exists" }
    end

    desc "Reset a user's password via reset token" do
      detail "Reset the user's password using a token received in the password reset email"
      success ApiV2::Entities::ApiResponse
      failure [
        [ 401, "Unauthorized - Invalid reset token" ],
        [ 422, "Unprocessable Entity - Password reset failed" ]
      ]
    end
    params do
      requires :token, type: String, desc: "Reset token from email"
      requires :password, type: String, desc: "New password"
      requires :password_confirmation, type: String, desc: "Password confirmation"
    end
    post :reset_password do
      user = User.load_from_reset_password_token(params[:token])
      error!({ message: "Invalid token" }, 401) unless user

      if params[:password] == params[:password_confirmation] &&
         user.change_password(params[:password])
        status 200
        { message: "Password has been reset successfully" }
      else
        error!({ message: "Password reset failed" }, 422)
      end
    end
  end

  helpers do
    def authenticate_user!(email, password)
      user = User.find_by(email:)
      if user&.valid_password?(password)
        [ user, jwt_for(user) ]
      else
        error!({ message: "Invalid email or password" }, 401)
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
  end
end
