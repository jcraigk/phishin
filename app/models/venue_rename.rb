class VenueRename < ApplicationRecord
  belongs_to :venue, touch: true

  validates :name, :renamed_on, presence: true
  validates :name, uniqueness: { scope: :renamed_on }
end
