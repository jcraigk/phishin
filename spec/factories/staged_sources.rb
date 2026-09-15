FactoryBot.define do
  factory :staged_source do
    show
    sequence(:position) { |n| n }
    sequence(:filename) { |n| "d1t#{sprintf('%02d', n)}.flac" }
    format { "flac" }
    offset_s { 0 }
    duration_s { 60 }
  end
end
