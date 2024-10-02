class ApiV2::Years < ApiV2::Base
  resource :years do
    desc "Fetch a list of years" do
      detail \
        "Fetch a list of years during which Phish has performed, " \
        "including era designations, the number of shows performed each " \
        "year, and unique venues count."
      success ApiV2::Entities::Year
    end
    get do
      present cached_years_data, with: ApiV2::Entities::Year
    end
  end

  helpers do
    def cached_years_data
      Rails.cache.fetch("api/v2/years") do
        years_data
      end
    end

    def years_data
      ERAS.map do |era, periods|
        periods.map do |period|
          shows_count, venues_count, shows_duration = stats_for(period)
          {
            period:,
            shows_count:,
            shows_duration:,
            venues_count:,
            era:
          }
        end
      end.flatten
    end

    def stats_for(period)
      shows = Show.published
      shows = if period.include?("-")
        shows.between_years(*period.split("-"))
      else
        shows.during_year(period)
      end

      [ shows.count, shows.select(:venue_id).distinct.count, shows.sum(:duration) ]
    end
  end
end
