# frozen_string_literal: true
FactoryBot.define do
  factory :playlist do
    name { "Playlist #{Faker::Book.unique.title}"[0..49] }
    slug { Faker::Internet.unique.slug(name, '-')[0..49] }

    user
  end
end
