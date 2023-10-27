FactoryBot.define do
  factory :track do
    sequence(:title) { |n| "Track #{n}" }
    songs { [build(:song)] }
    set { '1' }
    sequence(:position, 1)
    audio_file_data { ShrineTestData.attachment_data('audio_file.mp3') }
    waveform_png_data { ShrineTestData.attachment_data('waveform_image.png') }
    duration { 1_000 }

    show

    trait :with_likes do
      after(:build) do |track|
        create_list(:like, 2, likable: track)
      end
    end
  end
end
