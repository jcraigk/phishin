# frozen_string_literal: true
class TrackTag < ApplicationRecord
  belongs_to :track, counter_cache: :tags_count
  belongs_to :tag

  after_create  :increment_tag_count
  after_destroy :decrement_tag_count

  private

  def increment_tag_count
    Tag.increment_counter('tracks_count', tag_id)
  end

  def decrement_tag_count
    Tag.decrement_counter('tracks_count', tag_id)
  end
end
