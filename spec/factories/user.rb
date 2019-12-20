# frozen_string_literal: true
FactoryBot.define do
  factory :user do
    sequence(:username) { |n| "user_#{n}" }
    sequence(:email) { |n| "email-#{n}@example.com" }
    password { 'password' }
    password_confirmation { 'password' }

    trait :with_likes do
      likes { create_list(:like, 3) }
    end
  end
end
