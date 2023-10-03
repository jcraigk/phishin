FactoryBot.define do
  factory :song do
    sequence(:title) { |n| "Song #{n}" }
    lyrics { Faker::Lorem.paragraph }

    trait :with_tracks do
      after(:build) do |song|
        create_list(:track, 2, songs: [song])
      end
    end
  end
end
