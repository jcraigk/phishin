# frozen_string_literal: true
FactoryBot.define do
  factory :track do
    title { Faker::GratefulDead.song }
    songs { FactoryBot.create_list(:song, 2) }
    sequence(:position)
    audio_file { fixture_file_upload(Rails.root.join('spec', 'support', 'test.mp3'), 'audio/mp3') }
    set { '1' }

    trait :with_likes do
      likes { FactoryBot.create_list(:likes, 5) }
    end
  end
end
