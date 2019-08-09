# frozen_string_literal: true
class ApiKey < ApplicationRecord
  has_many :api_requests, dependent: :destroy

  scope :revoked, -> { where.not(revoked_at: nil) }
  scope :not_revoked, -> { where(revoked_at: nil) }
  scope :active, -> { not_revoked }

  validates :name, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true
  validates :key, presence: true, uniqueness: true

  before_validation :generate_key

  def revoke!
    update(revoked_at: Time.current)
  end

  def revoked?
    revoked_at.present?
  end

  private

  def generate_key
    return if key.present?
    self.key = SecureRandom.hex(48)
  end
end
