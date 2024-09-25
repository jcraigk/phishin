FactoryBot.define do
  factory :playlist do
    sequence(:name) { |n| "Playlist #{n}" }
    slug { name.downcase.gsub(/[^a-z0-9]/, '-') }
    published { true }

    user

    transient do
      tracks_count { 2 }
    end

    before(:create) do |playlist, evaluator|
      playlist.playlist_tracks = create_list(:playlist_track, evaluator.tracks_count, playlist:)
    end
  end
end
