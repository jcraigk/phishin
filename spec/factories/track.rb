FactoryBot.define do
  factory :track do
    sequence(:title) { |n| "Track #{n}" }
    songs { [ build(:song) ] }
    set { "1" }
    sequence(:position, 1)
    duration { 150_000 } # 2m 30s

    show

    transient do
      attachments { true }
    end

    after(:build) do |track, evaluator|
      if evaluator.attachments
        track.mp3_audio.attach \
          io: File.open(Rails.root.join("spec/fixtures/audio_file.mp3")),
          filename: "audio_file.mp3",
          content_type: "audio/mpeg"
        track.png_waveform.attach \
          io: File.open(Rails.root.join("spec/fixtures/waveform_image.png")),
          filename: "waveform_image.png",
          content_type: "image/png"
      end
    end

    trait :with_likes do
      after(:build) do |track|
        create_list(:like, 2, likable: track)
      end
    end
  end
end
