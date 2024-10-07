class SitemapRefreshJob
  include Sidekiq::Job

  def perform
    system("bundle exec rails sitemap:refresh:no_ping")
  end
end
