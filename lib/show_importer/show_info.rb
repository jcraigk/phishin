# frozen_string_literal: true
require 'open-uri'
require 'nokogiri'
require_relative '../pnet'

class ShowInfo
  PNET_API_KEY = '448345A7B7688DDE43D0'

  attr_reader :songs, :pnet

  def initialize(date)
    @pnet = PNet.new(PNET_API_KEY)
    @songs = {}
    @data = @pnet.shows_setlists_get('showdate' => date)[0] rescue {}
    songs = Nokogiri::HTML(@data['setlistdata']).css('p.pnetset > a').map(&:content) rescue []
    raise 'Invalid date' if songs.empty?
    songs.each_with_index { |song, i| @songs[i + 1] = song }
  end

  def [](pos)
    @songs[pos]
  end

  def venue_name
    @data['venue'] rescue 'Unknown Venue'
  end

  def venue_city
    @data['city'] rescue 'Unknown City'
  end
end
