# frozen_string_literal: true
FactoryBot.define do
  factory :track_tag do
    track
    tag

    trait :with_timestamps do
      starts_at_second { 1 }
      ends_at_second { 2 }
    end
  end
end
