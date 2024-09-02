class UserJwtService < BaseService
  param :user

  def call
    jwt_for_user
  end

  private

  def jwt_for_user
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
