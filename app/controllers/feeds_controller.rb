class FeedsController < ApplicationController
  def rss
    @announcements = Announcement.order(created_at: :desc)
    render layout: false
  end
end
