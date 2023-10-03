FactoryBot.define do
  factory :venue_rename do
    sequence(:name) { |n| "Venue Rename #{n}" }
    renamed_on { Faker::Date.unique.between(from: 500.years.ago, to: Time.zone.today) }

    venue
  end
end
