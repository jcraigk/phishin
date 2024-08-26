class GrapeApi::Announcements < GrapeApi::Base
  resource :announcements do
    desc "Return recent Announcements" do
      detail \
        "Fetches the 100 most recent Announcements, " \
        "ordered by creation date in descending order"
      success GrapeApi::Entities::Announcement
    end
    get do
      present \
        Announcement.order(created_at: :desc).limit(100),
        with: GrapeApi::Entities::Announcement
    end
  end
end
