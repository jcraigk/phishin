# frozen_string_literal: true
require 'mp3info'

class Track < ApplicationRecord
  belongs_to :show
  has_many :songs_tracks, dependent: :destroy
  has_many :songs, through: :songs_tracks
  has_many :likes, as: :likable, dependent: :destroy
  has_many :track_tags, dependent: :destroy
  has_many :tags, through: :track_tags
  has_many :playlist_tracks, dependent: :destroy

  has_attached_file(
    :audio_file,
    path: "#{APP_CONTENT_PATH}/:class/:attachment/:id_partition/:id.:extension"
  )

  extend FriendlyId
  friendly_id :title, use: :scoped, scope: :show

  include PgSearch
  pg_search_scope(
    :kinda_matching,
    against: :title,
    using: {
      tsearch: {
        any_word: true,
        normalization: 16
      }
    }
  )

  # TODO: fix validation
  # validates_attachment :audio_file, presence: true,
  #   content_type: { content_type: ['application/mp3', 'application/x-mp3', 'audio/mpeg', 'audio/mp3'] }
  do_not_validate_attachment_file_type :audio_file
  validates :position, :show, :title, :set, presence: true
  validates :position, uniqueness: { scope: :show_id }
  validates :songs, length: { minimum: 1 }

  after_commit :save_duration, on: :create

  scope :chronological, -> { joins(:show).order('shows.date') }
  scope :tagged_with, ->(tag_name) { joins(:tags).where(tags: { name: tag_name }) }

  def set_name
    set_names[set] || 'Unknown Set'
  end

  def save_default_id3_tags
    Mp3DefaultTagger.new(self).call
  end

  def generic_slug
    slug = title.downcase
                .delete("'")
                .gsub(/[^a-z0-9]/, ' ')
                .strip
                .gsub(/\s+/, ' ')
                .gsub(/\s/, '-')
    # Song title abbreviations
    slug.gsub!(/hold\-your\-head\-up/, 'hyhu')
    slug.gsub!(/the\-man\-who\-stepped\-into\-yesterday/, 'tmwsiy')
    slug.gsub!(/she\-caught\-the\-katy\-and\-left\-me\-a\-mule\-to\-ride/, 'she-caught-the-katy')
    slug.gsub!(/mcgrupp\-and\-the\-watchful\-hosemasters/, 'mcgrupp')
    slug.gsub!(/big\-black\-furry\-creature\-from\-mars/, 'bbfcfm')
    slug
  end

  def mp3_url
    APP_BASE_URL +
      '/audio/' +
      format('%<id>09d', id: id)
      .scan(/.{3}/)
      .join('/') + "/#{id}.mp3"
  end

  def save_duration
    Mp3Info.open(audio_file.path) do |mp3|
      update_column(:duration, (mp3.length * 1000).round)
    end
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
      updated_at: updated_at.to_s
    }
  end

  def as_json_api # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    {
      id: id,
      show_id: show.id,
      show_date: show.date.to_s,
      title: title,
      position: position,
      duration: duration,
      set: set,
      set_name: set_name,
      likes_count: likes_count,
      slug: slug,
      tags: tags.sort_by(&:priority).map(&:name).as_json,
      mp3: mp3_url,
      song_ids: songs.map(&:id),
      updated_at: updated_at.to_s
    }
  end

  private

  def set_names
    {
      'S' => 'Soundcheck',
      '1' => 'Set 1',
      '2' => 'Set 2',
      '3' => 'Set 3',
      '4' => 'Set 4',
      'E' => 'Encore',
      'E2' => 'Encore 2',
      'E3' => 'Encore 3'
    }
  end
end
