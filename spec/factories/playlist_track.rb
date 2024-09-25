FactoryBot.define do
  factory :playlist_track do
    sequence(:position, 1)

    starts_at_second { nil }
    ends_at_second { nil }

    playlist
    track
  end
end
