class ShowTag < ActiveRecord::Base
  attr_accessible :show_id, :tag_id, :created_at

  belongs_to :show
  belongs_to :tag

  after_create  :increment_tag_count
  after_destroy :decrement_tag_count

  private

  def increment_tag_count
    Tag.increment_counter('shows_count', self.tag_id)
  end

  def decrement_tag_count
    Tag.decrement_counter('shows_count', self.tag_id)
  end
end
