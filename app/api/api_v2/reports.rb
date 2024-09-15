class ApiV2::Reports < ApiV2::Base
  resource :reports do
    desc "Fetch a list of missing and incomplete content" do
      detail \
        "Returns a list of dates on which Phish is known to have played " \
        "but for which there is partial or nonexistent audio in cicurlation"
      success [ { code: 200, model: ApiV2::Entities::MissingContentReport } ]
    end
    get "missing_content" do
      present(
        {
          missing_show_dates:,
          incomplete_show_dates:
        },
        with: ApiV2::Entities::MissingContentReport
      )
    end
  end

  helpers do
    def complete_show_dates
      Show.published.where(incomplete: false).order(date: :desc).pluck(:date)
    end

    def incomplete_show_dates
      Show.published.where(incomplete: true).order(date: :desc).pluck(:date)
    end

    def missing_show_dates
      KnownDate.where.not(date: complete_show_dates + incomplete_show_dates)
               .where(date: ...Time.zone.today)
               .order(date: :desc)
               .pluck(:date)
    end
  end
end
