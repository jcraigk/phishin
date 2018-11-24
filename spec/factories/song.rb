# frozen_string_literal: true
FactoryBot.define do
  factory :song do
    title { "Song #{Faker::Book.title}" }
    alias_for { nil }

    trait :with_tracks do
      after(:build) do |song|
        create_list(:track, 2, songs: [song])
      end
    end
  end
end
