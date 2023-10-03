FactoryBot.define do
  factory :api_key do
    name { Faker::Name.unique.name }
    email { Faker::Internet.unique.email }

    trait :revoked do
      revoked_at { Time.current }
    end
  end
end
