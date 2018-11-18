# frozen_string_literal: true
FactoryBot.define do
  factory :user do
    username { (0...10).map { ('a'..'z').to_a[rand(26)] }.join }
    email { Faker::Internet.email }
    password { 'password' }
    password_confirmation { 'password' }
  end
end
