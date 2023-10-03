class TrackInserter
  attr_reader :date, :position, :file, :title, :song_id, :set, :track

  def initialize(opts = {})
    @date = opts[:date]
    @position = opts[:position].to_i
    @file = opts[:file]
    @title = opts[:title]
    @song_id = opts[:song_id] || Song.find_by(title:)&.id
    @set = opts[:set]

    ensure_valid_options
    ensure_records_present
  end

  def call
    shift_track_positions
    insert_new_track
    update_show_duration
  end

  private

  def shift_track_positions
    show.tracks
        .where('position >= ?', position)
        .order(position: :desc)
        .each { |t| t.update(position: t.position + 1) }
  end

  def show
    @show ||= Show.published.find_by(date:)
  end

  def insert_new_track
    track = Track.new(
      show:,
      title:,
      songs: [Song.find(song_id)],
      position:,
      set:
    )
    track.save!(validate: false) # Generate ID for audio_file storage
    track.update!(audio_file: File.open(file))
  end

  def update_show_duration
    show.save_duration
  end

  def ensure_valid_options
    raise 'Invalid options!' unless all_options_present?
  end

  def all_options_present?
    date && position && file && song_id && title && set
  end

  def ensure_records_present
    raise 'Invalid file!' unless File.exist?(file)
    raise 'Invalid song!' if song.blank?
    raise 'Invalid show!' if show.blank?
  end

  def song
    @song ||= Song.find_by(id: song_id)
  end
end
