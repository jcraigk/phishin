class ApiV2::Admin::Shows < ApiV2::Admin::Base
  helpers ApiV2::Helpers::AdminHelper

  before { authenticate_admin! }

  namespace :admin do
    resource :shows do
      desc "List shows for admin", hidden: true
      params do
        optional :published, type: Boolean, desc: "Filter by published state"
      end
      get do
        shows = Show.order(date: :desc)
        shows = shows.where(published: params[:published]) unless params[:published].nil?
        {
          shows: shows.limit(500).map { |show| show_summary(show) }
        }
      end
    end
  end

  helpers do
    def show_summary(show)
      {
        id: show.id,
        date: show.date.iso8601,
        venue_name: show.venue_name,
        published: show.published,
        audio_status: show.audio_status,
        tracks_count: show.tracks.count,
        duration: show.duration
      }
    end
  end
end
