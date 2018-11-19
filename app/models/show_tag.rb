# frozen_string_literal: true
class ShowTag < ApplicationRecord
  belongs_to :show, counter_cache: :tags_count
  belongs_to :tag, counter_cache: :shows_count
end
