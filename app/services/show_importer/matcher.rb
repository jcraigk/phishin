class ShowImporter::Matcher
  Result = Struct.new(:venue, :tour, :show_info, :tracks, keyword_init: true)

  SET_MAP = {
    "3" => %w[III],
    "E" => %w[E e I-e II-e III-e],
    "2" => %w[II],
    "1" => %w[I],
    "S" => %w[(Check)]
  }.freeze

  def self.call(date:, filenames:)
    new(date:, filenames:).call
  end

  def initialize(date:, filenames:)
    @date = date
    @filenames = filenames
    @used_files = []
  end

  def call
    Result.new(venue:, tour:, show_info:, tracks: build_tracks)
  end

  private

  attr_reader :date, :filenames

  def show_info
    @show_info ||= ShowImporter::ShowInfo.new(date)
  end

  def filename_matcher
    @filename_matcher ||= ShowImporter::FilenameMatcher.new(filenames:)
  end

  def venue
    @venue ||=
      Venue.left_outer_joins(:venue_renames)
           .where(
             "(venues.name = :name OR venue_renames.name = :name) AND city = :city",
             name: show_info.venue_name,
             city: show_info.venue_city
           ).first
  end

  def tour
    @tour ||= Tour.where("starts_on <= :date AND ends_on >= :date", date:).first
  end

  def build_tracks
    show_info.songs.map do |position, title|
      build_track(position, title)
    end
  end

  def build_track(position, title)
    set = show_info.sets[position]

    if (match = fn_match?(title))
      filename = match.first
      song = match.second
      {
        position:,
        filename:,
        title: song&.title || title,
        set: set || musical_set_from_fn(filename),
        song_id: song&.id
      }
    elsif (song = filename_matcher.find_song(title, exact: true))
      { position:, title: song.title, set:, filename: nil, song_id: song.id }
    else
      { position:, title:, set:, filename: nil, song_id: nil }
    end
  end

  def fn_match?(title)
    filename_matcher.matches
                    .except(*@used_files)
                    .find { |_k, v| !v.nil? && v.title.casecmp?(title) }
                    .tap { |k, _v| @used_files << k if k }
  end

  def musical_set_from_fn(filename)
    SET_MAP.each do |set, values|
      values.each do |value|
        return set if filename&.start_with?(value)
      end
    end

    "1"
  end
end
