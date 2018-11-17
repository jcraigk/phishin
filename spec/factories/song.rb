# frozen_string_literal: true
FactoryBot.define do
  factory :song do
    title { Faker::GratefulDead.song }

    trait :with_tracks do
      tracks { FactoryBot.create_list(:track, 5) }
    end
  end
end
