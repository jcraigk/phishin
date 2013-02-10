class Song < ActiveRecord::Base
  attr_accessible :title, :songs_count

  has_and_belongs_to_many :tracks
  scope :random, lambda { |amt| where('tracks_count > 0').order('RANDOM()').limit(amt) }

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
end
