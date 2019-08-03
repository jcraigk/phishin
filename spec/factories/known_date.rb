# frozen_string_literal: true
FactoryBot.define do
  factory :known_date do
    date { Faker::Date.unique.between(from: 500.years.ago, to: Date.today) }
    phishnet_url { 'http://phish.net/some-url' }
    location { "#{Faker::Address.city}, #{Faker::Address.state}" }
    venue { "Venue #{Faker::Address.unique.community}"[0..40] }
  end
end
