# frozen_string_literal: true
FactoryBot.define do
  factory :playlist do
    name { "Playlist #{Faker::Book.unique.title[0..50]}" }
    slug { Faker::Internet.unique.slug(name, '-')[0..50] }

    user
  end
end
