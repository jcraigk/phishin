class ApiV2::Announcements < ApiV2::Base
  resource :announcements do
    desc "Fetch recent announcements" do
      detail "Fetch the newest 100 announcements"
      success ApiV2::Entities::Announcement
    end
    get do
      present announcements, with: ApiV2::Entities::Announcement
    end
  end

  helpers do
    def announcements
      Rails.cache.fetch(cache_key_for_custom("announcements")) do
        Announcement.order(created_at: :desc).limit(100)
      end
    end
  end
end
