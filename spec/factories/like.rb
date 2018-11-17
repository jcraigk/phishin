# frozen_string_literal: true
FactoryBot.define do
  factory :like do
    user

    trait :for_track do
      likable { FactoryBot.create(:track) }
    end

    trait :for_show do
      likable { FactoryBot.create(:show) }
    end
  end
end
