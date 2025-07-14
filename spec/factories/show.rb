FactoryBot.define do
  factory :show do
    sequence(:date) { |n| Date.new(1985, 1, 1) + n.days }
    taper_notes { Faker::Lorem.paragraph }
    audio_status { 'complete' }

    tour
    venue

    trait :with_tracks do
      after(:build) do |show|
        create_list(:track, 3, show:)
      end
    end

    trait :with_likes do
      likes { build_list(:like, 3) }
    end

    trait :with_tags do
      tags { build_list(:tag, 2) }
    end
  end
end
