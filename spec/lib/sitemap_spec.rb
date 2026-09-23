require "rails_helper"

RSpec.describe "config/sitemap.rb" do # rubocop:disable RSpec/DescribeClass
  let(:output_dir) { Dir.mktmpdir }
  let(:urls) do
    File.read(File.join(output_dir, "sitemap", "sitemap.xml")).scan(%r{<loc>([^<]+)</loc>})
      .flatten.map { |url| URI(url).path }
  end

  before do
    create(:tag, slug: "debut")
    SitemapGenerator::Sitemap.public_path = output_dir
    SitemapGenerator::Sitemap.compress = false
    SitemapGenerator::Sitemap.verbose = false
    load Rails.root.join("config/sitemap.rb")
  end

  after do
    SitemapGenerator::Sitemap.public_path = "public/"
    SitemapGenerator::Sitemap.compress = true
    FileUtils.remove_entry(output_dir)
  end

  it "uses the hyphenated tag routes the app serves" do
    expect(urls).to include("/show-tags/debut", "/track-tags/debut")
  end

  it "omits account and auth pages" do
    expect(urls).not_to include(
      "/login", "/signup", "/request-password-reset", "/my-shows", "/my-tracks"
    )
  end
end
