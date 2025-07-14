FactoryBot.define do
  factory :tour do
    sequence(:name) { |n| "Tour #{n}" }
    sequence(:starts_on) { |n| Date.new(1985, 1, 1) + (n * 30).days }
    sequence(:ends_on) { |n| Date.new(1985, 1, 1) + (n * 30 + 10).days }

    trait :with_shows do
      after(:build) do |tour|
        create_list(:show, 2, tour:)
      end
    end
  end
end
