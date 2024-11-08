class ApiV2::Years < ApiV2::Base
  COVER_ART = {
    "1983-1987" => "1983-12-02",
    "1988" => "1988-12-10",
    "1989" => "1989-10-20",
    "1990" => "1990-10-06",
    "1991" => "1991-04-04",
    "1992" => "1992-03-12",
    "1993" => "1993-03-27",
    "1994" => "1994-11-25",
    "1995" => "1995-12-09",
    "1996" => "1996-12-31",
    "1997" => "1997-12-31",
    "1998" => "1998-11-20",
    "1999" => "1999-12-31",
    "2000" => "2000-07-10",
    "2002" => "2002-12-19",
    "2003" => "2003-08-01",
    "2004" => "2004-04-15",
    "2009" => "2009-08-14",
    "2010" => "2010-12-27",
    "2011" => "2011-06-30",
    "2012" => "2012-06-23",
    "2013" => "2013-07-05",
    "2014" => "2014-12-31",
    "2015" => "2015-07-21",
    "2016" => "2016-10-28",
    "2017" => "2017-01-13",
    "2018" => "2018-12-31",
    "2019" => "2019-11-29",
    "2020" => "2020-02-20",
    "2021" => "2021-09-03",
    "2022" => "2022-07-26",
    "2023" => "2023-10-06",
    "2024" => "2024-10-25"
  }

  resource :years do
    desc "Fetch a list of years" do
      detail \
        "Fetch a list of years during which Phish has performed, " \
        "including era designations, the number of shows performed each " \
        "year, unique venues count, and selected cover art."
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
          shows_count, venues_count, shows_duration, cover_art_urls = stats_for(period)
          {
            period:,
            shows_count:,
            shows_duration:,
            venues_count:,
            cover_art_urls:,
            era:
          }
        end
      end.flatten
    end

    def stats_for(period)
      shows = Show.published
      shows =
        if period.include?("-")
          shows.between_years(*period.split("-"))
        else
          shows.during_year(period)
        end
      cover_art_urls = Show.find_by(date: COVER_ART[period]).cover_art_urls
      [ shows.count, shows.select(:venue_id).distinct.count, shows.sum(:duration), cover_art_urls ]
    end
  end
end
