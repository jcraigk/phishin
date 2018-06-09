# frozen_string_literal: true
require 'mp3info'

class Track < ApplicationRecord
  has_attached_file :audio_file,
    path: APP_CONTENT_PATH + ":class/:attachment/:id_partition/:id.:extension"

  belongs_to :show
  has_many :songs_tracks, dependent: :destroy
  has_many :songs, through: :songs_tracks
  has_many :likes, as: :likable, dependent: :destroy
  has_many :track_tags, dependent: :destroy
  has_many :tags, through: :track_tags
  has_many :playlist_tracks, dependent: :destroy

  self.per_page = 10 # will_paginate default

  scope :chronological, -> { order('shows.date ASC').joins(:show) }
  scope :tagged_with, ->(tag) { includes(:tags).where('tags.name = ?', tag) }

  include PgSearch
  pg_search_scope :kinda_matching,
                  against: :title,
                  using: {
                    tsearch: {
                      any_word: false,
                      normalization: 16
                    }
                  }

  # validates_attachment :audio_file, presence: true,
  #   content_type: { content_type: ['application/mp3', 'application/x-mp3', 'audio/mpeg', 'audio/mp3'] }
  do_not_validate_attachment_file_type :audio_file
  validates_presence_of :show, :title, :position
  validates_uniqueness_of :position, scope: :show_id
  validate :require_at_least_one_song

  before_validation :populate_song, :populate_position
  after_save :save_duration

  def should_generate_new_friendly_id?; true; end

  # Return the full name of the set given the stored codes
  def set_name
    case set
      when "S" then "Soundcheck"
      when "1" then "Set 1"
      when "2" then "Set 2"
      when "3" then "Set 3"
      when "4" then "Set 4"
      when "E" then "Encore"
      when "E2" then "Encore 2"
      when "E3" then "Encore 3"
      else "Unknown set"
    end
  end

  # Return the set abbreviation (livephish.com style)
  # Roman numerals; encores are part of final set
  def set_album_abbreviation
    # Encores
    if /^E[\d]*$/.match(set)
      romanize show.last_set
    # Numbered sets
    elsif /^\d$/.match(set)
      romanize set
    else
      ""
    end
  end

  def save_default_id3_tags
    Mp3Info.open(audio_file.path) do |mp3|
      mp3.tag.title = title
      mp3.tag.artist = 'Phish'
      mp3.tag.album = "#{show.date} #{set_album_abbreviation} #{show.venue.location}"
      mp3.tag.year = show.date.strftime('%Y').to_i
      mp3.tag.track = position
      mp3.tag.genre = 'Rock'
      mp3.tag.comment = 'Visit phish.in for free Phish audio'

      mp3.tag2.title = title
      mp3.tag2.artist = 'Phish'
      mp3.tag2.album = "#{show.date} #{set_album_abbreviation} #{show.venue.location}"
      mp3.tag2.year = show.date.strftime('%Y').to_i
      mp3.tag2.track = position
      mp3.tag2.genre = 'Rock'
      mp3.tag2.comment = 'Visit phish.in for free Phish audio'

      # TODO: Add cover art using id3v2?
      # mp3.tag2.remove_pictures
      # mp3.tag2.add_picture(file.read)
    end
  end

  def generic_slug
    slug = title.downcase.gsub(/\'/, '').gsub(/[^a-z0-9]/, ' ').strip.gsub(/\s+/, ' ').gsub(/\s/, '-')
    # handle abbreviations
    slug.gsub!(/hold\-your\-head\-up/, 'hyhu')
    slug.gsub!(/the\-man\-who\-stepped\-into\-yesterday/, 'tmwsiy')
    slug.gsub!(/she\-caught\-the\-katy\-and\-left\-me\-a\-mule\-to\-ride/, 'she-caught-the-katy')
    slug.gsub!(/mcgrupp\-and\-the\-watchful\-hosemasters/, 'mcgrupp')
    slug.gsub!(/big\-black\-furry\-creature\-from\-mars/, 'bbfcfm')
    slug
  end

  def mp3_url
    APP_BASE_URL + '/audio/' + sprintf('%09d', id).scan(/.{3}/).join('/') + "/#{id}.mp3"
  end

  def as_json
    {
      id: id,
      title: title,
      position: position,
      duration: duration,
      set: set,
      set_name: set_name,
      likes_count: likes_count,
      slug: slug,
      mp3: mp3_url,
      song_ids: songs.map(&:id),
      updated_at: updated_at
    }
  end

  def as_json_api
    {
      id: id,
      show_id: show.id,
      show_date: show.date,
      title: title,
      position: position,
      duration: duration,
      set: set,
      set_name: set_name,
      likes_count: likes_count,
      slug: slug,
      tags: tags.map(&:name).as_json,
      mp3: mp3_url,
      song_ids: songs.map(&:id),
      updated_at: updated_at
    }
  end

  def as_json_for_playlist_api
    {
      id: id,
      show_id: show_id,
      show_date: show.date,
      title: title,
      position: position,
      duration: duration,
      set: set,
      set_name: set_name,
      likes_count: likes_count,
      slug: slug,
      tags: tags.map(&:name).as_json,
      mp3: mp3_url,
      songs: songs.as_json,
      updated_at: updated_at
    }
  end

  def save_duration
    unless self.duration # this won't record the correct duration if we're uploading a new file
      Mp3Info.open audio_file.path do |mp3|
        self.duration = (mp3.length * 1000).round
        save
      end
    end
  end

  protected

  def populate_song
    if songs.empty?
      song = Song.where 'lower(title) = ?', self.title.downcase
      self.songs << song if song
    end
  rescue
  end

  def populate_position
    # If we don't have a position and there is at least 1 previous song in the show
    if !self.position && !(last_song = Track.where(:show_id => show.id).last).nil?
      self.position = last_song.position + 1
    elsif !self.position
      self.position = 1
    end
  end

  def require_at_least_one_song
    errors.add(:songs, "Please add at least one song") if songs.empty?
  rescue
  end

  def romanize(number)
    case number
      when "1" then "I"
      when "2" then "II"
      when "3" then "III"
      when "4" then "IV"
      else ""
    end
  end

  # Do not allow tracks to be destroyed
  def prevent_destruction
    false
  end

end