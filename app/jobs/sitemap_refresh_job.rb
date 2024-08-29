class SitemapRefreshJob
  include Sidekiq::Job

  def perform
    system("bundle exec rake -s sitemap:refresh")
  end
end
