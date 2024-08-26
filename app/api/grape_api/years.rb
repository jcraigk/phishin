class GrapeApi::Years < GrapeApi::Base
  desc "Years during which Phish performed live shows"
  resource :years do
    desc \
      "Return a list of years during which Phish performed live shows, " \
        "including era designations"
    get do
      present cached_years_data, with: GrapeApi::Entities::Year
    end
  end

  helpers do
    def years_data
      ERAS.map do |era, periods|
        periods.map do |period|
          {
            period:,
            shows_count: shows_count_for(period),
            era:
          }
        end
      end.flatten
    end

    def shows_count_for(period)
      shows = Show.published
      return shows.between_years(*period.split("-")).count if period.include?("-")
      shows.during_year(period).count
    end

    def cached_years_data
      Rails.cache.fetch("api/v2/years") do
        years_data
      end
    end
  end
end
