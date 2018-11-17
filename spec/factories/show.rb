# frozen_string_literal: true
FactoryBot.define do
  factory :show do
    tour
    venue

    trait :with_tracks do
      tracks { FactoryBot.create_list(:track, 5) }
    end

    trait :with_likes do
      likes { FactoryBot.create_list(:like, 5) }
    end

    trait :with_tags do
      tags { FactoryBot.create_list(:tag, 5) }
    end
  end
end
