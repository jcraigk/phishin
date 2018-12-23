# frozen_string_literal: true
FactoryBot.define do
  factory :tour do
    name { "Tour #{Faker::Book.unique.title}"[0..49] }
    starts_on { Faker::Date.unique.between(30.years.ago, Date.today) }
    ends_on { Faker::Date.unique.between(30.years.ago, Date.today) }

    trait :with_shows do
      after(:build) do |tour|
        create_list(:show, 2, tour: tour)
      end
    end
  end
end
