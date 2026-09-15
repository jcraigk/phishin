class Admin::ShowMatchAssigner
  def self.call(show)
    new(show).call
  end

  def initialize(show)
    @show = show
  end

  def call
    return if @show.venue && @show.tour
    match = ShowImporter::Matcher.call(date: @show.date.to_s, filenames: [])
    @show.venue ||= match.venue
    @show.tour ||= match.tour
    @show.save!
  rescue ShowImporter::ShowInfo::NotFoundError
    nil
  end
end
