class Track < ApplicationRecord
  include TrackApiV1
  include HasAudioStatus

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
  after_save :update_show_audio_status
  after_destroy :update_show_audio_status
  after_create :increment_tracks_with_audio_counter_caches
  after_update :update_tracks_with_audio_counter_caches, if: :saved_change_to_audio_status?
  after_destroy :decrement_tracks_with_audio_counter_caches

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
    return if missing_audio?
    Id3TagService.call(self)
  end

  def generate_slug(force: false)
    return if !force && slug.present?
    self.slug = TrackSlugGenerator.call(self)
  end

  def mp3_url
    return if missing_audio?
    blob_url(mp3_audio, placeholder: "audio.mp3", ext: :mp3)
  end

  def waveform_image_url
    return if missing_audio?
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
    return if missing_audio?
    WaveformImageService.call(self)
  end

  def process_mp3_audio
    return if missing_audio?
    save_duration
    show.save_duration
    apply_id3_tags
    generate_waveform_image
  end

  private

  def save_duration
    return if missing_audio?
    mp3_audio.analyze unless mp3_audio.analyzed?
    duration_ms = (mp3_audio.blob.metadata[:duration] * 1000).round
    update_column(:duration, duration_ms)
  end

  def update_show_audio_status
    show.update_audio_status_from_tracks!
  end

  def increment_tracks_with_audio_counter_caches
    return if missing_audio?
    increment_tracks_with_audio_counters
  end

  def update_tracks_with_audio_counter_caches
    old_audio_status = saved_changes["audio_status"][0]
    new_audio_status = saved_changes["audio_status"][1]

    if old_audio_status == "missing" && new_audio_status.in?(%w[complete partial])
      increment_tracks_with_audio_counters
    elsif old_audio_status.in?(%w[complete partial]) && new_audio_status == "missing"
      decrement_tracks_with_audio_counters
    end
  end

  def decrement_tracks_with_audio_counter_caches
    return if missing_audio?
    decrement_tracks_with_audio_counters
  end

  def increment_tracks_with_audio_counters
    songs.each { |song| song.increment!(:tracks_with_audio_count) }
  end

  def decrement_tracks_with_audio_counters
    songs.each { |song| song.decrement!(:tracks_with_audio_count) }
  end
end
