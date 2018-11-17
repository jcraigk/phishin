# frozen_string_literal: true
FactoryBot.define do
  factory :tag do
    name { Faker::Hacker.noun }
    color { Faker::Color.hex_color }
    description { Faker::Lorem.sentence }
    sequence(:priority)

    trait :with_tracks do
      tracks { FactoryBot.create_list(:track, 5) }
    end

    trait :for_show do
      shows { FactoryBot.create_list(:show, 5) }
    end
  end
end
