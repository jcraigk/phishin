# frozen_string_literal: true
class Track < ApplicationRecord
  belongs_to :show
  has_many :songs_tracks, dependent: :destroy
  has_many :songs, through: :songs_tracks
  has_many :likes, as: :likable, dependent: :destroy
  has_many :track_tags, dependent: :destroy
  has_many :tags, through: :track_tags
  has_many :playlist_tracks, dependent: :destroy

  include AudioFileUploader::Attachment(:audio_file)
  validates :audio_file, presence: true

  include WaveformImageUploader::Attachment(:waveform_image)

  include PgSearch::Model
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

  validates :position, :title, :set, presence: true
  validates :position, uniqueness: { scope: :show_id }
  validates :songs, length: { minimum: 1 }

  before_save :generate_slug

  scope :chronological, -> { joins(:show).order('shows.date') }
  scope :tagged_with, ->(tag_slug) { joins(:tags).where(tags: { slug: tag_slug }) }

  def url
    "#{APP_BASE_URL}/#{show.date.to_formatted_s(:db)}/#{slug}"
  end

  def set_name
    SET_NAMES[set] || 'Unknown Set'
  end

  def apply_id3_tags
    Id3Tagger.new(self).call
  end

  def generate_slug(force: false)
    return if !force && slug.present?
    self.slug = TrackSlugGenerator.new(self).call
  end

  def mp3_url
    audio_file.url(host: APP_BASE_URL).gsub('tracks/audio_files', 'audio')
  end

  def waveform_image_url
    waveform_image&.url(host: APP_BASE_URL)&.gsub('tracks/audio_files', 'audio')
  end

  def save_duration
    update_column(:duration, Mp3DurationQuery.new(audio_file.to_io.path).call)
  end

  def generate_waveform_image
    WaveformImageGenerator.new(self).call
  end

  def extract_waveform_data
    WaveformDataExtractor.new(self).call
  end

  def as_json # rubocop:disable Metrics/MethodLength
    {
      id:,
      title:,
      position:,
      duration:,
      jam_starts_at_second:,
      set:,
      set_name:,
      likes_count:,
      slug:,
      mp3: mp3_url,
      waveform_image: waveform_image_url,
      song_ids: songs.map(&:id),
      updated_at: updated_at.iso8601
    }
  end

  def as_json_api # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    {
      id:,
      show_id: show.id,
      show_date: show.date.iso8601,
      venue_name: show.venue_name,
      venue_location: show.venue.location,
      title:,
      position:,
      duration:,
      jam_starts_at_second:,
      set:,
      set_name:,
      likes_count:,
      slug:,
      tags: track_tags_for_api,
      mp3: mp3_url,
      waveform_image: waveform_image_url,
      song_ids: songs.map(&:id),
      updated_at: updated_at.iso8601
    }
  end

  def process_audio_file
    save_duration
    apply_id3_tags
    generate_waveform_image
  end

  private

  def partitioned_id
    format('%<id>09d', id:).scan(/.{3}/).join('/')
  end

  def track_tags_for_api # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    tags = track_tags.map do |tt|
      {
        id: tt.tag.id,
        name: tt.tag.name,
        priority: tt.tag.priority,
        group: tt.tag.group,
        color: tt.tag.color,
        notes: tt.notes,
        transcript: tt.transcript,
        starts_at_second: tt.starts_at_second,
        ends_at_second: tt.ends_at_second
      }
    end
    tags.sort_by { |t| t[:priority] }
  end
end
