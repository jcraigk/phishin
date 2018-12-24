# frozen_string_literal: true
require 'rails_helper'
require 'mp3info'

RSpec.describe Id3Tagger do
  subject(:service) { described_class.new(track) }

  let(:show) { create(:show, date: "#{year}-10-31") }
  let(:track) { create(:track, position: position, title: title, show: show) }
  let(:year) { 1995 }
  let(:position) { 2 }
  let(:title) { 'Bathtub Gin' }
  let(:artist) { 'Phish' }
  let(:album) { "#{track.show.date} #{track.show.venue_name}"[0..29] }
  let(:comments) { 'http://phish.in for more' }

  before { service.call }

  it 'sets id3 tags on track mp3' do
    Mp3Info.open(track.audio_file.path) do |mp3|
      tag = mp3.tag
      expect(tag.title).to eq(title)
      expect(tag.tracknum).to eq(position)
      expect(tag.artist).to eq(artist)
      expect(tag.album).to eq(album)
      expect(tag.year).to eq(year)
      expect(tag.comments).to eq(comments)
    end
  end

  it 'sets id3v2 tags on track mp3' do
    Mp3Info.open(track.audio_file.path) do |mp3|
      tag2 = mp3.tag2
      expect(tag2.TIT2).to eq(title)
      expect(tag2.TRCK).to eq(position.to_s)
      expect(tag2.TOPE).to eq(artist)
      expect(tag2.TALB).to eq(album)
      expect(tag2.TYER).to eq(year.to_s)
      expect(tag2.COMM).to eq(comments)
    end
  end
end
