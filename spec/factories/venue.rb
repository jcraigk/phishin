# frozen_string_literal: true
FactoryBot.define do
  factory :venue do
    name { Faker::Address.community }
    city { Faker::Address.city }
    state { Faker::Address.state }
    country { Faker::Address.country }
    longitude { Faker::Address.latitude }
    longitude { Faker::Address.longitude }

    trait :with_shows do
      shows { FactoryBot.create_list(:shows, 5) }
    end
  end
end
