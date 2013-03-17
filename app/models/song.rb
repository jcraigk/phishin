class Song < ActiveRecord::Base
  attr_accessible :title, :tracks_count

  has_and_belongs_to_many :tracks
  
  scope :random, ->(amt=1) { where('tracks_count > 0').order('RANDOM()').limit(amt) }

  validates_presence_of :title

  extend FriendlyId
  friendly_id :title, :use => :slugged

  include PgSearch
  pg_search_scope :kinda_matching,
                  :against => :title, 
                  :using => {
                    tsearch: {
                      any_word: true,
                      normalization: 16
                    }
                  }
  scope :relevant, -> { where('tracks_count > 0 or alias_for IS NOT NULL') }
  scope :random_lyrical_excerpt, -> { where('lyrical_excerpt IS NOT NULL').order('RANDOM()') }
  
  def title_letter
    title[0,1]
  end
  
  def aliased_song
    Song.where(id: alias_for).first if alias_for
  end
  
end
