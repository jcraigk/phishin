# frozen_string_literal: true
class TrackInsertionService
  attr_reader :date, :position, :file, :title, :song_id, :set, :is_sbd, :track

  def initialize(opts = {})
    @date = opts[:date]
    @position = opts[:position].to_i
    @file = opts[:file]
    @title = opts[:title]
    @song_id = opts[:song_id] || Song.find_by!(title: title).id
    @set = opts[:set]
    @is_sbd = opts[:is_sbd]

    ensure_valid_options
    ensure_records_present
  end

  def call
    shift_track_positions
    insert_new_track
    add_sbd_tag
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
    @show ||= Show.find_by(date: date)
  end

  def insert_new_track
    @track = Track.create(
      show: show,
      title: title,
      songs: [Song.find(song_id)],
      audio_file: File.new(file, 'r'),
      position: position,
      set: set
    )
  end

  def add_sbd_tag
    return unless is_sbd
    track.tags << Tag.find_by(name: 'SBD')
  end

  def update_show_duration
    show.save_duration
  end

  def ensure_valid_options
    raise 'Invalid options!' unless date && position && file && song_id && title && set
  end

  def ensure_records_present
    raise 'Invalid file!' unless File.exist?(file)
    raise 'Invalid song!' unless song.present?
    raise 'Invalid show!' unless show.present?
  end

  def song
    @song ||= Song.find_by(id: song_id)
  end
end
