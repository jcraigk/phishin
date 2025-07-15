FactoryBot.define do
  factory :track do
    sequence(:title) { |n| "Track #{n}" }
    songs { [ build(:song) ] }
    set { "1" }
    sequence(:position, 1)
    duration { 150_000 } # 2m 30s
    exclude_from_performance_gaps { false }

    show

    trait :with_likes do
      after(:build) do |track|
        create_list(:like, 2, likable: track)
      end
    end
  end
end
