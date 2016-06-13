class Song < ActiveRecord::Base
  attr_accessible :title, :tracks_count

  has_and_belongs_to_many :tracks

  scope :random, ->(amt=1) { where('tracks_count > 0').order('RANDOM()').limit(amt) }

  validates_presence_of :title

  extend FriendlyId
  friendly_id :title, use: :slugged

  include PgSearch
  pg_search_scope :kinda_matching,
                  against: :title,
                  using: {
                    tsearch: {
                      any_word: true,
                      normalization: 16
                    }
                  }
  scope :relevant, -> { where('tracks_count > 0 or alias_for IS NOT NULL') }
  scope :random_lyrical_excerpt, -> { where('lyrical_excerpt IS NOT NULL').order('RANDOM()') }
  scope :title_starting_with, ->(char) { where("title SIMILAR TO ?", "#{char == '#' ? '[0-9]' : char}%") }

  def title_letter
    title[0,1]
  end

  def aliased_song
    Song.where(id: alias_for).first if alias_for
  end

  def is_alias?
    !alias_for.nil?
  end

  def as_json
    {
      id: id,
      title: title,
      alias_for: alias_for,
      tracks_count: tracks_count,
      slug: slug,
      updated_t: updated_at
    }
  end

  def as_json_api
    {
      id: id,
      title: title,
      alias_for: alias_for,
      tracks_count: tracks_count,
      slug: slug,
      updated_at: updated_at,
      tracks: tracks.sort_by { |t| t.show.date }.map do |t|
        {
          id: t.id,
          title: t.title,
          duration: t.duration,
          show_id: t.show.id,
          show_date: t.show.date,
          set: t.set,
          position: t.position,
          likes_count: t.likes_count,
          slug: t.slug,
          mp3: t.mp3_url
        }
      end
    }
  end
end
