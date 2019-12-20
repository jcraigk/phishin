# frozen_string_literal: true
FactoryBot.define do
  factory :track do
    sequence(:title) { |n| "Track #{n}" }
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
  end
end
