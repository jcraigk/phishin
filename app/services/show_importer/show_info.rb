# frozen_string_literal: true
class ShowImporter::ShowInfo
  BASE_URL = 'https://api.phish.net/v5'
  API_KEY = ENV['PNET_API_KEY']

  attr_reader :date, :data, :songs

  def initialize(date)
    @date = date
    @data = fetch_pnet_data
    @songs ||= {}

    raise "Date \"#{date}\" not found on Phish.net" if data.none?

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
    JSON.parse(Typhoeus.get(phishnet_api_url).body, object_class: OpenStruct).data
  end

  def phishnet_api_url
    "#{BASE_URL}/setlists/showdate/#{date}.json?apikey=#{API_KEY}"
  end
end
