# frozen_string_literal: true
FactoryBot.define do
  factory :show do
    date { Faker::Date.between(30.years.ago, Date.today) }
    missing { true }
    taper_notes { Faker::Lorem.paragraph }

    tour
    venue

    trait :with_tracks do
      tracks { build_list(:track, 5) }
    end

    trait :with_likes do
      likes { build_list(:like, 5) }
    end

    trait :with_tags do
      tags { build_list(:tag, 2) }
    end
  end
end
