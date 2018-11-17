# frozen_string_literal: true
FactoryBot.define do
  factory :user do
    sequence(:username) { |n| "username#{n}" }
    email { Faker::Internet.email }
    password 'password'
    password_confirmation 'password'
  end
end
