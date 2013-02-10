class Show < ActiveRecord::Base
  attr_accessible :date, :location, :sbd, :remastered

  belongs_to :tour
  belongs_to :venue
  has_many :tracks, :dependent => :destroy

  scope :for_year, lambda { |year|
    if year == '83-87'
      where('date between ? and ?', 
              Date.new(1983).beginning_of_year, 
              Date.new(1987).end_of_year).order(:date)
    else
      date = Date.new(year.to_i)
      where('date between ? and ?', 
              date.beginning_of_year, 
              date.end_of_year).order(:date)
    end
  }

  validates_presence_of :date, :location

  extend FriendlyId
  friendly_id :date

  def to_s
    "#{date.strftime('%m-%d-%Y')} - #{location}" if date && location
  end
  alias_method :title, :to_s # for rails admin
  
  def last_set
    tracks.select { |t| /^\d$/.match t.set }.map(&:set).sort.last
  end
end
