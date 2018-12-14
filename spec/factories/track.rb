# frozen_string_literal: true
FactoryBot.define do
  factory :track do
    title { Faker::Book.title[0..50] }
    songs { [build(:song)] }
    set { '1' }
    sequence(:position, 1)
    audio_file { Rack::Test::UploadedFile.new('spec/fixtures/test.mp3', 'audio/mp3') }

    show

    trait :with_likes do
      after(:build) do |track|
        create_list(:like, 2, likable: track)
      end
    end

    trait :with_tags do
      after(:build) do |track|
        create_list(:track_tag, 2, track: track, tag: create(:tag))
      end
    end
  end
end
