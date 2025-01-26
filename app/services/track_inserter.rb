class TrackInserter
  attr_reader :date, :position, :file, :title, :song_id, :set, :track, :slug

  def initialize(opts = {})
    @date = opts[:date]
    @position = opts[:position].to_i
    @file = opts[:file]
    @title = opts[:title]
    @song_id = opts[:song_id] || Song.find_by(title:)&.id
    @set = opts[:set]
    @slug = opts[:slug]

    ensure_valid_options
    ensure_records_present
  end

  def call
    shift_track_positions
    insert_new_track
  end

  private

  def shift_track_positions
    show.tracks
        .where(position: position..)
        .order(position: :desc)
        .each { |t| t.update(position: t.position + 1) }
  end

  def show
    @show ||= Show.find_by(date:)
  end

  def insert_new_track
    track = Track.new(
      show:,
      title:,
      songs: [ Song.find(song_id) ],
      position:,
      set:
    )
    track.slug = slug if slug.present?
    track.save!
    track.mp3_audio.attach(io: File.open(file), filename: File.basename(file))
    track.process_mp3_audio
  end

  def ensure_valid_options
    raise "Invalid options!" unless all_options_present?
  end

  def all_options_present?
    date && position && file && song_id && title && set
  end

  def ensure_records_present
    raise "Invalid file!" unless File.exist?(file)
    raise "Invalid song!" if song.blank?
    raise "Invalid show!" if show.blank?
  end

  def song
    @song ||= Song.find_by(id: song_id)
  end
end
