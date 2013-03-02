class Show < ActiveRecord::Base
  
  attr_accessible :date, :location, :sbd, :remastered, :likes_count
  extend FriendlyId
  friendly_id :date

  has_many :tracks, :dependent => :destroy
  belongs_to :tour, counter_cache: true
  belongs_to :venue, counter_cache: true
  has_many :likes, as: :likable

  validates_presence_of :date, :location

  scope :during_year, ->(year) {
    date = Date.new(year.to_i)
    where('date between ? and ?', 
      date.beginning_of_year, 
      date.end_of_year)
  }
  scope :between_years, ->(year1, year2) {
    date1 = Date.new(year1.to_i)
    date2 = Date.new(year2.to_i)
    if date1 < date2
      where('date between ? and ?', 
        date1.beginning_of_year, 
        date2.end_of_year).order('date')
    else
      where('date between ? and ?', 
        date2.beginning_of_year, 
        date1.end_of_year)
    end
  }

  def to_s
    "#{date.strftime('%m-%d-%Y')} - #{venue.location}"
  end
  
  def last_set
    tracks.select { |t| /^\d$/.match t.set }.map(&:set).sort.last
  end
end
