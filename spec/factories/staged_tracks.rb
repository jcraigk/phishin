FactoryBot.define do
  factory :staged_track do
    show
    sequence(:position) { |n| n }
    set { "1" }
    sequence(:title) { |n| "Staged #{n}" }
    start_s { 0 }
    end_s { 60 }
  end
end
