class GrapeApi::Announcements < GrapeApi::Base
  resource :announcements do
    desc "Return the most recent 100 Announcements"
    get do
      announcements = Announcement.order(created_at: :desc).limit(100)
      present announcements, with: GrapeApi::Entities::Announcement
    end
  end
end
