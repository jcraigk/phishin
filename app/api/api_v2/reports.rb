class ApiV2::Reports < ApiV2::Base
  resource :reports do
    desc "Fetch a list of missing and incomplete content" do
      detail \
        "Returns a list of dates on which Phish is known to have played " \
        "but for which there is partial or nonexistent audio in circulation"
      success [
        { code: 200, model: ApiV2::Entities::MissingContentReport }
      ]
    end

    get "missing_content" do
      present(
        {
          missing_shows: missing_show_details,
          incomplete_shows: incomplete_show_details
        },
        with: ApiV2::Entities::MissingContentReport
      )
    end
  end

  helpers do
    def complete_show_dates
      Show.published.where(incomplete: false).pluck(:date)
    end

    def incomplete_show_details
      Show.published.where(incomplete: true).order(date: :desc).map do |show|
        {
          date: show.date,
          venue_name: show.venue_name,
          location: show.venue.location
        }
      end
    end

    def missing_show_details
      KnownDate.where.not(date: complete_show_dates)
               .where(date: ...Time.zone.today)
               .order(date: :desc)
               .map do |kd|
        {
          date: kd.date,
          venue_name: kd.venue,
          location: kd.location
        }
      end
    end
  end
end
