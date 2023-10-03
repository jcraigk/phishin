FactoryBot.define do
  factory :playlist do
    sequence(:name) { |n| "Playlist #{n}" }
    slug { name.downcase.gsub(/[^a-z0-9]/, '-') }

    user
  end
end
