class Announcement < ApplicationRecord
  def self.announce_show!(show)
    url = show.url
    return if exists?(url:)
    show_name = "#{show.date} at #{show.venue_name}"
    create!(
      title: "New content: #{show_name}",
      description: "A new show has been added: #{show_name}",
      url:
    )
  end
end
