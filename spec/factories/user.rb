# frozen_string_literal: true
FactoryBot.define do
  factory :user do
    username { Faker::Internet.username }
    email { Faker::Internet.email }
    password { Faker::Internet.password }
    password_confirmation { Faker::Internet.password }
  end
end
