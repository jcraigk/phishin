module SorceryAuthenticable
  extend ActiveSupport::Concern

  included do
    authenticates_with_sorcery!

    has_many :authentications, dependent: :destroy

    validates :email, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :password, length: { minimum: 5 }, if: :password
    validates :password, confirmation: true, if: :password
  end

  def verified?
    activation_state == "active"
  end

  def resend_verification_email
    setup_activation
    save!
    send(:send_activation_needed_email!)
  end
end
