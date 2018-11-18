# frozen_string_literal: true
FactoryBot.define do
  factory :playlist do
    name { Faker::Book.title }
    slug { Faker::Internet.slug(name, '-') }

    user

    after(:create) do |playlist|
      playlist.tracks = FactoryBot.create_list(:track, 5)
    end
  end
end
