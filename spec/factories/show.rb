# frozen_string_literal: true
FactoryBot.define do
  factory :show do
    date { Faker::Date.between(30.years.ago, Date.today) }
    missing { false }
    taper_notes { Faker::Lorem.paragraph }

    tour
    venue

    trait :with_tracks do
      after(:build) do |show|
        create_list(:track, 3, show: show)
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
