FactoryBot.define do
  factory :venue do
    sequence(:name) { |n| "Venue #{n}" }
    city { Faker::Address.city }
    state { Faker::Address.state }
    country { Faker::Address.country }
    latitude { Faker::Address.latitude }
    longitude { Faker::Address.longitude }

    trait :with_shows do
      after(:build) do |venue|
        create_list(:show, 2, venue:)
      end
    end
  end
end
