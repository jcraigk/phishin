FactoryBot.define do
  factory :playlist_track do
    sequence(:position, 1)

    playlist
    track
  end
end
