require "zlib"

class SitemapController < ActionController::Base
  def show
    path = Rails.root.join("public", "sitemap", "sitemap.xml.gz")
    return head(:not_found) unless File.exist?(path)

    expires_in 1.hour, public: true
    send_data(
      Zlib::GzipReader.open(path, &:read),
      type: "application/xml",
      disposition: "inline",
      filename: "sitemap.xml"
    )
  end
end
