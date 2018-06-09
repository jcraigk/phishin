# frozen_string_literal: true
class AlbumRequest < ApplicationRecord
  has_one :user
  has_one :album
end
