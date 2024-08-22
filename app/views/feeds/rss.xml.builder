xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0" do
  xml.channel do
    xml.title "#{App.app_name} Updates"
    xml.description App.app_desc
    xml.link App.base_url

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
