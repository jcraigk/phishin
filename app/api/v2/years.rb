
class Api::V2::Years < Grape::API
  helpers do
    def years_data
      ERAS.values.flatten.map do |year|
        {
          period: year,
          show_count: show_count_for(year),
          era: era_for_year(year)
        }
      end
    end

    def show_count_for(year)
      shows = Show.published
      return shows.between_years("1983", "1987").count if year == "1983-1987"
      shows.during_year(year).count
    end

    def era_for_year(year)
      ERAS.find { |_, years| years.include?(year) }&.first
    end
  end

  resource :years do
    desc "Return a list of years during which Phish performed"
    get do
      present years_data
    end
  end
end
