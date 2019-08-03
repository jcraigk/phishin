# frozen_string_literal: true
FactoryBot.define do
  factory :venue_rename do
    name { "Venue #{Faker::Address.unique.community}"[0..40] }
    renamed_on { Faker::Date.unique.between(from: 500.years.ago, to: Date.today) }

    venue
  end
end
