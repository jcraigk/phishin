# frozen_string_literal: true
class TrackRequest < ApplicationRecord
  has_one :user
  has_one :track
end
