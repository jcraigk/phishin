# frozen_string_literal: true
FactoryBot.define do
  factory :playlist_bookmark do
    playlist
    user
  end
end
