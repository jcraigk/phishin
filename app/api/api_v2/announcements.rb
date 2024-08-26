class ApiV2::Announcements < ApiV2::Base
  resource :announcements do
    desc "Return recent Announcements" do
      detail \
        "Fetches the 100 most recent Announcements, " \
        "ordered by creation date in descending order"
      success ApiV2::Entities::Announcement
    end
    get do
      present \
        Announcement.order(created_at: :desc).limit(100),
        with: ApiV2::Entities::Announcement
    end
  end
end
