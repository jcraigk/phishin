# frozen_string_literal: true
FactoryBot.define do
  factory :tour do
    sequence(:name) { |n| "Tour #{n}" }
    starts_on { Faker::Date.unique.between(from: 500.years.ago, to: Time.zone.today) }
    ends_on { Faker::Date.unique.between(from: 500.years.ago, to: Time.zone.today) }

    trait :with_shows do
      after(:build) do |tour|
        create_list(:show, 2, tour:)
      end
    end
  end
end
