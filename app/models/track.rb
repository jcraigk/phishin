# frozen_string_literal: true
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

  do_not_validate_attachment_file_type :audio_file
  validates :position, :show, :title, :set, presence: true
  validates :position, uniqueness: { scope: :show_id }
  validates :songs, length: { minimum: 1 }

  before_validation :generate_slug
  after_commit :save_duration, on: :create

  scope :chronological, -> { joins(:show).order('shows.date') }
  scope :tagged_with, ->(tag_slug) { joins(:tags).where(tags: { slug: tag_slug }) }

  def url
    "#{APP_BASE_URL}/#{show.date.to_s(:db)}/#{slug}"
  end

  def set_name
    SET_NAMES[set] || 'Unknown Set'
  end

  def apply_id3_tags
    Id3Tagger.new(self).call
  end

  def generate_slug
    return if slug.present?
    self.slug = TrackSlugGenerator.new(self).call
  end

  def mp3_url
    "#{APP_BASE_URL}/audio/#{partitioned_id}/#{id}.mp3"
  end

  def save_duration
    update(duration: Mp3DurationQuery.new(audio_file.path).call)
  end

  def as_json # rubocop:disable Metrics/MethodLength
    {
      id: id,
      title: title,
      position: position,
      duration: duration,
      jam_starts_at_second: jam_starts_at_second,
      set: set,
      set_name: set_name,
      likes_count: likes_count,
      slug: slug,
      mp3: mp3_url,
      song_ids: songs.map(&:id),
      updated_at: updated_at.iso8601
    }
  end

  def as_json_api # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    {
      id: id,
      show_id: show.id,
      show_date: show.date.iso8601,
      title: title,
      position: position,
      duration: duration,
      jam_starts_at_second: jam_starts_at_second,
      set: set,
      set_name: set_name,
      likes_count: likes_count,
      slug: slug,
      tags: track_tags_for_api,
      mp3: mp3_url,
      song_ids: songs.map(&:id),
      updated_at: updated_at.iso8601
    }
  end

  private

  def partitioned_id
    format('%<id>09d', id: id).scan(/.{3}/).join('/')
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
