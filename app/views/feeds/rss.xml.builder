xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0" do
  xml.channel do
    xml.title "#{APP_NAME} Updates"
    xml.description APP_DESC
    xml.link APP_BASE_URL

    @announcements.each do |announcement|
      xml.item do
        xml.title announcement.title
        xml.description announcement.description
        xml.pubDate announcement.created_at.to_fs(:rfc822)
        xml.link announcement.url
      end
    end
  end
end
