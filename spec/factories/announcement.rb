# frozen_string_literal: true
FactoryBot.define do
  factory :announcement do
    title { "New show: #{Faker::Date}" }
    description { "New content added: #{Faker::Date}" }
    url { "#{APP_BASE_URL}/#{Faker::Date}" }
  end
end
