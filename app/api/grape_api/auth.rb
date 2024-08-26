require "jwt"

class GrapeApi::Auth < GrapeApi::Base
  resource :auth do
    desc "User login via email and password" do
      detail "Authenticates a User using their email and password and returns a JWT"
      success GrapeApi::Entities::LoginResponse
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
        with: GrapeApi::Entities::LoginResponse
      )
    end

    desc "Get currently logged in user" do
      detail "Fetches the currently authenticated User"
      success GrapeApi::Entities::User
      failure [ [ 401, "Unauthorized - Invalid JWT" ] ]
    end
    get :user do
      authenticate!
      present current_user, with: GrapeApi::Entities::User
    end

    desc "Request password reset email" do
      detail "Sends a password reset email to the User if found"
      success GrapeApi::Entities::ApiResponse
    end
    params do
      requires :email, type: String, desc: "User email"
    end
    post :send_password_reset_email do
      user = User.find_by(email: params[:email])
      user&.deliver_reset_password_instructions!
      status 200
      { message: "If the email exists, reset instructions have been sent" }
    end

    desc "Reset a User's password via reset token" do
      detail "Resets the User's password using a token received in the password reset email"
      success code: 200, message: "Password has been reset successfully"
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
