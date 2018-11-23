# frozen_string_literal: true
FactoryBot.define do
  factory :playlist do
    name { Faker::Book.unique.title }
    slug { Faker::Internet.unique.slug(name, '-') }

    user

    trait :with_tracks do
      after(:build) do |playlist|
        create_list(:playlist_track, 2, playlist: playlist)
      end
    end
  end
end
