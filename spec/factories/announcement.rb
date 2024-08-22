FactoryBot.define do
  factory :announcement do
    title { "New show: #{Faker::Date}" }
    description { "New content added: #{Faker::Date}" }
    url { "#{App.base_url}/#{Faker::Date}" }
  end
end
