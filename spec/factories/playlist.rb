# frozen_string_literal: true
FactoryBot.define do
  factory :playlist do
    name { Faker::Book.title }
    slug { Faker::Internet.slug(name, '-') }

    user

    trait :with_tracks do
      after(:build) do |playlist|
        create_list(:playlist_track, 2, playlist: playlist)
      end
    end
  end
end
