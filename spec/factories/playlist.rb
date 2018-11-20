# frozen_string_literal: true
FactoryBot.define do
  factory :playlist do
    name { Faker::Book.title }
    slug { Faker::Internet.slug(name, '-') }

    user

    trait :with_tracks do
      after(:create) do |playlist|
        5.times do |idx|
          create(:playlist_track, playlist: playlist, track: create(:track), position: idx)
        end
      end
    end
  end
end
