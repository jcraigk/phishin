# frozen_string_literal: true
FactoryBot.define do
  factory :playlist do
    name { Faker::Book.unique.title }
    slug { Faker::Internet.unique.slug(name, '-') }

    user
  end
end
