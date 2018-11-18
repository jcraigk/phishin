# frozen_string_literal: true
FactoryBot.define do
  factory :track do
    title { Faker::Book.title }
    songs { [build(:song)] }
    set { '1' }
    sequence(:position, 1)
    audio_file { Rack::Test::UploadedFile.new('spec/support/test.mp3', 'audio/mp3') }

    show

    trait :with_likes do
      likes { build_list(:likes, 5) }
    end
  end
end
