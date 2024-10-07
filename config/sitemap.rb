SitemapGenerator::Sitemap.default_host = App.base_url
SitemapGenerator::Sitemap.sitemaps_path = "sitemap/"
SitemapGenerator::Sitemap.create do # rubocop:disable Metrics/BlockLength
  # Static pages
  add "/api-docs"
  add "/contact-info"
  add "/faq"
  add "/privacy"
  add "/tagin-project"
  add "/terms"

  # Auth
  add "/login"
  add "/signup"
  add "/request-password-reset"

  # Misc pages
  add "/map"
  add "/missing-content"
  add "/my-shows"
  add "/my-tracks"
  add "/playlists"
  add "/search"
  add "/tags"
  add "/today"
  add "/top-shows"
  add "/top-tracks"

  # Years
  ERAS.values.flatten.each do |year|
    add "/#{year}"
  end

  # Songs
  add "/songs"
  Song.find_each do |song|
    add "/songs/#{song.slug}", lastmod: song.updated_at
  end

  # Venues
  add "/venues"
  Venue.find_each do |venue|
    add "/venues/#{venue.slug}", lastmod: venue.updated_at
  end

  # Tags
  add "/tags"
  Tag.find_each do |tag|
    add "/show_tags/#{tag.slug}",
        lastmod: tag.show_tags.order(created_at: :desc).first&.created_at
    add "/track_tags/#{tag.slug}",
        lastmod: tag.track_tags.order(created_at: :desc).first&.created_at
  end

  # Shows
  Show.published.find_each do |show|
    add "/#{show.date}", lastmod: show.updated_at
  end

  # Tracks
  Track.includes(:show).find_each do |track|
    add "/#{track.show.date}/#{track.slug}", lastmod: track.updated_at
  end

  # Playlists
  add "/playlists"
  Playlist.published.find_each do |playlist|
    add "/play/#{playlist.slug}", lastmod: playlist.updated_at
  end
end
