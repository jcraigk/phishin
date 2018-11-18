# frozen_string_literal: true
FactoryBot.define do
  factory :like do
    user

    trait :for_track do
      likable { build(:track) }
    end

    trait :for_show do
      likable { build(:show) }
    end
  end
end
