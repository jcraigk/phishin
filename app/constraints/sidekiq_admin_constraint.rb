class SidekiqAdminConstraint
  COOKIE = "sidekiq_admin".freeze
  TTL = 12.hours

  def self.token_for(user)
    verifier.generate(user.id, purpose: :sidekiq_admin, expires_in: TTL)
  end

  def self.user_from(token)
    user_id = verifier.verified(token, purpose: :sidekiq_admin)
    user_id && User.find_by(id: user_id, admin: true)
  end

  def self.verifier
    Rails.application.message_verifier(COOKIE)
  end

  def matches?(request)
    token = request.cookie_jar[COOKIE]
    token.present? && self.class.user_from(token).present?
  end
end
