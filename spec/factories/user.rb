# frozen_string_literal: true
FactoryBot.define do
  factory :user do
    username { (0...10).map { ('a'..'z').to_a[rand(26)] }.join }
    email { Faker::Internet.email }
    password { 'password' }
    password_confirmation { 'password' }

    trait :with_likes do
      likes { create_list(:like, 3) }
    end
  end
end
