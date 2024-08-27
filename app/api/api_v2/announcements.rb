class ApiV2::Announcements < ApiV2::Base
  resource :announcements do
    desc "Return recent announcements" do
      detail "Returns the 100 newest announcements"
      success ApiV2::Entities::Announcement
    end
    get do
      present \
        Announcement.order(created_at: :desc).limit(100),
        with: ApiV2::Entities::Announcement
    end
  end
end
