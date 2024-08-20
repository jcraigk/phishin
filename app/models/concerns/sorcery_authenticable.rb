module SorceryAuthenticable
  extend ActiveSupport::Concern

  included do
    authenticates_with_sorcery!

    has_many :authentications, dependent: :destroy

    validates \
      :username,
      presence: true,
      uniqueness: true,
      format: {
        with: /\A[A-Za-z0-9_]{4,15}\z/,
        message: "may contain only letters, numbers, and " \
                "underscores, must be unique, and must be " \
                "4 to 15 characters long"
      }
    validates :email, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :password, length: { minimum: 5 }, if: :password
    validates :password, confirmation: true, if: :password

    before_validation :assign_username_from_email

    private

    def assign_username_from_email
      return if username.present?

      name = email.split("@").first.gsub(/[^A-Za-z0-9_]/, "_")
      name = "#{name.first(10)}_#{SecureRandom.hex(2)}" if User.where(username: name).exists?
      self.username = name
    end
  end
end
