class ApiV2::Years < ApiV2::Base
  COVER_ART = {
    "1983-1987" => "1985-10-30",
    "1988" => "1988-12-10",
    "1989" => "1989-10-13",
    "1990" => "1990-05-23",
    "1991" => "1991-05-16",
    "1992" => "1992-03-12",
    "1993" => "1993-07-16",
    "1994" => "1994-11-25",
    "1995" => "1995-06-30",
    "1996" => "1996-08-15",
    "1997" => "1997-12-31",
    "1998" => "1998-11-02",
    "1999" => "1999-12-31",
    "2000" => "2000-07-10",
    "2002" => "2002-12-19",
    "2003" => "2003-08-01",
    "2004" => "2004-04-15",
    "2009" => "2009-11-27",
    "2010" => "2010-10-29",
    "2011" => "2011-06-30",
    "2012" => "2012-06-07",
    "2013" => "2013-07-05",
    "2014" => "2014-12-31",
    "2015" => "2015-07-21",
    "2016" => "2016-10-28",
    "2017" => "2017-01-13",
    "2018" => "2018-08-31",
    "2019" => "2019-12-28",
    "2020" => "2020-02-20",
    "2021" => "2021-08-10",
    "2022" => "2022-07-26",
    "2023" => "2023-10-06",
    "2024" => "2024-04-18",
    "2025" => "2025-04-22"
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
      Rails.cache.fetch(cache_key_for_custom("years")) do
        years_data
      end
    end

    def years_data
      # Preload cover to avoid N+1 queries
      cover_art_dates = COVER_ART.values.compact
      cover_art_shows = Show.includes(
        cover_art_attachment: {
          blob: {
            variant_records: { image_attachment: :blob }
          }
        }
      ).where(date: cover_art_dates).index_by(&:date)

      # Calculate all statistics in batches to reduce queries
      all_periods = ERAS.values.flatten
      batch_stats = calculate_batch_statistics(all_periods)

      ERAS.map do |era, periods|
        periods.map do |period|
          stats = batch_stats[period]
          cover_art_urls = get_cover_art_urls(period, cover_art_shows)

          {
            period:,
            shows_count: stats[:shows_count],
            shows_with_audio_count: stats[:shows_with_audio_count],
            shows_duration: stats[:shows_duration],
            venues_count: stats[:venues_count],
            venues_with_audio_count: stats[:venues_with_audio_count],
            era:,
            cover_art_urls:
          }
        end
      end.flatten
    end

    private

    def calculate_batch_statistics(periods)
      stats_query = periods.map do |period|
        condition = if period.include?("-")
          year1, year2 = period.split("-")
          date1 = Date.new(year1.to_i).beginning_of_year
          date2 = Date.new(year2.to_i).end_of_year
          "date BETWEEN '#{date1}' AND '#{date2}'"
        else
          "date_part('year', date) = #{period}"
        end

        <<~SQL
          SELECT
            '#{period}' as period,
            COUNT(*) as shows_count,
            COUNT(CASE WHEN audio_status IN ('complete', 'partial') THEN 1 END) as shows_with_audio_count,
            COUNT(DISTINCT venue_id) as venues_count,
            COUNT(DISTINCT CASE WHEN audio_status IN ('complete', 'partial') THEN venue_id END) as venues_with_audio_count,
            COALESCE(SUM(duration), 0) as shows_duration
          FROM shows
          WHERE (#{condition})
        SQL
      end

      union_query = stats_query.join(" UNION ALL ")

      results = ActiveRecord::Base.connection.execute(union_query)

      results.each_with_object({}) do |row, hash|
        hash[row["period"]] = {
          shows_count: row["shows_count"].to_i,
          shows_with_audio_count: row["shows_with_audio_count"].to_i,
          venues_count: row["venues_count"].to_i,
          venues_with_audio_count: row["venues_with_audio_count"].to_i,
          shows_duration: row["shows_duration"].to_i
        }
      end
    end

    def get_cover_art_urls(period, cover_art_shows)
      cover_art_date_string = COVER_ART[period]
      return nil unless cover_art_date_string

      cover_art_date = Date.parse(cover_art_date_string)
      cover_art_shows[cover_art_date]&.cover_art_urls
    end
  end
end
