require 'ostruct'

class ShowImporter::ShowInfo
  BASE_URL = 'https://api.phish.net/v5'.freeze
  API_KEY = ENV.fetch('PNET_API_KEY', nil)

  attr_reader :date, :data, :songs

  def initialize(date)
    @date = date
    @data = fetch_pnet_data
    @songs ||= {}

    abort "Date \"#{date}\" not found on Phish.net" if data.none?

    populate_songs
  end

  def venue_name
    data.first.venue
  end

  def venue_city
    data.first.city
  end

  private

  def populate_songs
    data.each { |t| @songs[t.position] = t.song }
  end

  def fetch_pnet_data
    JSON.parse(Typhoeus.get(phishnet_api_url).body, object_class: OpenStruct).data # rubocop:disable Style/OpenStructUse
  end

  def phishnet_api_url
    "#{BASE_URL}/setlists/showdate/#{date}.json?apikey=#{API_KEY}"
  end
end
