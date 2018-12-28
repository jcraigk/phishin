# frozen_string_literal: true
FactoryBot.define do
  factory :api_request do
    api_key
    path { '/some/request/path' }
  end
end
