# frozen_string_literal: true
FactoryBot.define do
  factory :tour do
    name { "#{Faker::Vehicle.year} Tour" }
    starts_on { Faker::Date.between(30.years.ago, Date.today) }
    ends_on { Faker::Date.between(30.years.ago, Date.today) }

    trait :with_shows do
      after(:build) do |tour|
        tour.shows = build_list(:show, 5, tour: tour)
      end
    end
  end
end
