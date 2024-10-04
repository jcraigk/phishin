class Track < ApplicationRecord
  include TrackApiV1

  belongs_to :show
  has_many :songs_tracks, dependent: :destroy
  has_many :songs, through: :songs_tracks
  has_many :likes, as: :likable, dependent: :destroy
  has_many :track_tags, dependent: :destroy
  has_many :tags, through: :track_tags
  has_many :playlist_tracks, dependent: :destroy

  include AudioFileUploader::Attachment(:audio_file)
  validates :audio_file, presence: true

  include WaveformPngUploader::Attachment(:waveform_png)

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
  after_update :process_audio_file, if: :saved_change_to_audio_file_data

  scope :chronological, -> { joins(:show).order("shows.date") }
  scope :tagged_with, ->(tag_slug) { joins(:tags).where(tags: { slug: tag_slug }) }

  def self.by_url(url)
    segments = URI.parse(url).path.split("/")
    Track.joins(:show).find_by(shows: { date: segments[-2] }, slug: segments[-1])
  end

  def url
    "#{App.base_url}/#{show.date}/#{slug}"
  end

  def set_name
    SET_NAMES[set] || "Unknown Set"
  end

  def apply_id3_tags
    Id3TagService.new(self).call
  end

  def generate_slug(force: false)
    return if !force && slug.present?
    self.slug = TrackSlugGenerator.new(self).call
  end

  def mp3_url
    audio_file.url(host: App.content_base_url).gsub("tracks/audio_files", "audio")
  end

  def waveform_image_url
    waveform_png&.url(host: App.content_base_url)&.gsub("tracks/audio_files", "audio")
  end

  def urls
    {
      web: url,
      mp3: mp3_url,
      img: waveform_image_url
    }
  end

  def save_duration
    update_column(:duration, Mp3DurationQuery.new(audio_file.to_io.path).call)
  end

  def generate_waveform_image(purge_cache: false)
    WaveformImageGenerator.new(self).call
    CloudflareCachePurgeService.call(waveform_image_url) if purge_cache
  end

  def process_audio_file
    return if Rails.env.test?
    save_duration
    show.save_duration
    apply_id3_tags
    generate_waveform_image
  end
end
