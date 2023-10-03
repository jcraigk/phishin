FactoryBot.define do
  factory :known_date do
    date { Faker::Date.unique.between(from: 500.years.ago, to: Time.zone.today) }
    phishnet_url { 'http://phish.net/some-url' }
    location { "#{Faker::Address.city}, #{Faker::Address.state}" }
    sequence(:venue) { |n| "Venue #{n}" }
  end
end
