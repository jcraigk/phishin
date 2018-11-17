# frozen_string_literal: true
FactoryBot.define do
  factory :playlist do
    user

    name { Faker::Book.title }

    trait :with_tracks do
      tracks { FactoryBot.create_list(:track, 5) }
    end
  end
end
