# frozen_string_literal: true
class PlaylistBookmark < ApplicationRecord
  belongs_to :playlist
  belongs_to :user
end
