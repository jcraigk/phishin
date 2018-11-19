# frozen_string_literal: true
FactoryBot.define do
  factory :playlist do
    name { Faker::Book.title }
    slug { Faker::Internet.slug(name, '-') }

    user

    trait :with_tracks do
      tracks { build_list(:track, 5) }
    end
  end
end
