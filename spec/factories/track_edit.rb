FactoryBot.define do
  factory :track_edit do
    track
    show { track.show }
    operation { "trim" }
    payload { {} }
  end
end
