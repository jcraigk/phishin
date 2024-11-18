class Track < ApplicationRecord
  include TrackApiV1

  belongs_to :show, touch: true
  has_many :songs_tracks, dependent: :destroy
  has_many :songs, through: :songs_tracks
  has_many :likes, as: :likable, dependent: :destroy
  has_many :track_tags, dependent: :destroy
  has_many :tags, through: :track_tags
  has_many :playlist_tracks, dependent: :destroy

  has_one_attached :mp3_audio
  has_one_attached :png_waveform

  include PgSearch::Model
  pg_search_scope(
    :kinda_matching,
    against: :title,
    using: { tsearch: { any_word: true, normalization: 16 } }
  )

  validates :position, :title, :set, presence: true
  validates :position, uniqueness: { scope: :show_id }
  validates :songs, length: { minimum: 1 }

  before_save :generate_slug

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
    Id3TagService.call(self)
  end

  def generate_slug(force: false)
    return if !force && slug.present?
    self.slug = TrackSlugGenerator.call(self)
  end

  def mp3_url
    blob_url(mp3_audio, placeholder: "audio.mp3", ext: :mp3)
  end

  def waveform_image_url
    blob_url(png_waveform, placeholder: "waveform.png", ext: :png)
  end

  def urls
    {
      web: url,
      mp3: mp3_url,
      img: waveform_image_url
    }
  end

  def generate_waveform_image(purge_cache: false)
    WaveformImageService.call(self)
  end

  def process_mp3_audio
    save_duration
    show.save_duration
    apply_id3_tags
    generate_waveform_image
  end

  private

  def save_duration
    mp3_audio.analyze unless mp3_audio.analyzed?
    duration_ms = (mp3_audio.blob.metadata[:duration] * 1000).round
    update_column(:duration, duration_ms)
  end
end
