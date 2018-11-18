# frozen_string_literal: true
FactoryBot.define do
  factory :playlist_track do
    position { 12 }
    # sequence(:position) { |n| "#{n}".to_i }

    playlist
    track
  end
end
