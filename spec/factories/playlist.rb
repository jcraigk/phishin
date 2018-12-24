# frozen_string_literal: true
FactoryBot.define do
  factory :playlist do
    name { "Playlist #{Faker::Book.unique.title}"[0..40] }
    slug { name.downcase.gsub(/[^a-z0-9]/, '-') }

    user
  end
end
