# frozen_string_literal: true
require 'open-uri'
require 'nokogiri'

class ShowImporter::ShowInfo
  attr_reader :songs, :pnet

  def initialize(date)
    @pnet = ShowImporter::PNet.new(ENV['PNET_API_KEY'])
    @data = parse_data(date)
    songs = parse_songs
    raise 'Invalid date' if songs.empty?

    @songs = {}
    songs.each_with_index do |song, i|
      @songs[i + 1] = song
    end
  end

  def parse_data(date)
    @pnet.shows_setlists_get('showdate' => date)[0]
  rescue NoMethodError
    {}
  end

  def parse_songs
    Nokogiri.HTML(@data['setlistdata'])
            .css('p.pnetset > a')
            .map(&:content)
  rescue NoMethodError
    []
  end

  def [](pos)
    @songs[pos]
  end

  def venue_name
    @data['venue']
  rescue NoMethodError
    'Unknown Venue'
  end

  def venue_city
    @data['city']
  rescue NoMethodError
    'Unknown City'
  end
end
