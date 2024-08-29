SitemapGenerator::Sitemap.default_host = App.base_url
SitemapGenerator::Sitemap.sitemaps_path = 'sitemap/'
SitemapGenerator::Sitemap.create do # rubocop:disable Metrics/BlockLength
  # Static pages
  add "/api-docs"
  add "/contact-info"
  add "/faq"
  add "/privacy"
  add "/tagin-project"
  add "/terms"

  # Auth
  add login_path
  add new_user_path
  add new_password_reset_path

  # Misc pages
  add "/map"
  add "/missing-content"
  add "/my-shows"
  add "/my-tracks"
  add "/playlist"
  add "/playlists"
  add "/tags"
  add "/today-in-history"
  add "/top-shows"
  add "/top-tracks"

  # Years
  ERAS.values.flatten.each do |year|
    add "/#{year}"
  end

  # Tours
  Tour.find_each do |tour|
    add tour.slug, lastmod: tour.updated_at
  end

  # Songs
  add "/songs"
  Song.find_each do |song|
    add song.slug, lastmod: song.updated_at
  end

  # Venues
  add "/venues"
  Venue.find_each do |venue|
    add venue.slug, lastmod: venue.updated_at
  end

  # Shows
  Show.published.find_each do |show|
    add show.date, lastmod: show.updated_at
  end

  # Tracks
  Track.includes(:show).find_each do |track|
    add "#{track.show.date}/#{track.slug}", lastmod: track.updated_at
  end
end
