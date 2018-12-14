# frozen_string_literal: true
class VenueRename < ApplicationRecord
  belongs_to :venue

  validates :name, :renamed_on, presence: true
  validates :name, uniqueness: { scope: :renamed_on }
end
