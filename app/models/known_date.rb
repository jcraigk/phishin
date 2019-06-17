# frozen_string_literal: true
class KnownDate < ApplicationRecord
  validates :date, uniqueness: true
  validates :phishnet_url, :venue, :location, presence: true

  def date_with_dots
    date.strftime('%Y.%m.%d')
  end
end
