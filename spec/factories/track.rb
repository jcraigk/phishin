# frozen_string_literal: true
FactoryBot.define do
  factory :track do
    title { Faker::Book.title }
    songs { [build(:song)] }
    set { '1' }
    sequence(:position, 1)
    audio_file { Rack::Test::UploadedFile.new('spec/fixtures/test.mp3', 'audio/mp3') }

    show

    trait :with_likes do
      after(:build) do |track|
        track.likes = build_list(:like, 5, likable: track)
      end
    end

    trait :with_tags do
      after(:build) do |track|
        track.tags = build_list(:tag, 2, tracks: track)
      end
    end
  end
end
