# frozen_string_literal: true
require 'open-uri'
require 'nokogiri'

class ShowImporter::ShowInfo
  attr_reader :song_titles, :pnet, :data

  def initialize(date)
    @date = date
    @pnet = ShowImporter::PNet.new(ENV['PNET_API_KEY'])
    @data = parse_data

    populate_initial_setlist
  end

  def populate_initial_setlist
    song_titles = parse_song_titles
    if song_titles.empty?
      puts "Date \"#{@date}\" not found on Phish.net!"
      song_titles = ['You Enjoy Myself']
    end

    @song_titles = {}
    song_titles.each_with_index do |song, i|
      @song_titles[i + 1] = song
    end
  end

  def parse_data
    @pnet.shows_setlists_get('showdate' => @date)[0]
  end

  def parse_song_titles
    Nokogiri.HTML(@data['setlistdata']).css('p.pnetset > a').map(&:content)
  rescue NoMethodError
    []
  end

  def [](pos)
    @song_titles[pos]
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
