# frozen_string_literal: true
FactoryBot.define do
  factory :playlist_track do
    sequence(:position) { |n| "#{n}".to_i }

    playlist
    track
  end
end
