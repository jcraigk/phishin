module SorceryAuthenticable
  extend ActiveSupport::Concern

  included do
    authenticates_with_sorcery!

    has_many :authentications, dependent: :destroy

    validates :email, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :password, length: { minimum: 5 }, if: :password
    validates :password, confirmation: true, if: :password
  end
end
