# frozen_string_literal: true
class ShowImporter::TrackProxy
  attr_accessor :filename

  def initialize(pos = nil, title = nil, filename = nil, song = nil)
    @_track = Track.new(position: pos, title: title, set: get_set_from_filename(filename), slug: generic_slug(title))
    song ||= Song.find_by_title(title)
    @_track.songs << song unless song.nil?
    @filename = filename
  end

  def generic_slug(title)
    title ? title.downcase.delete("'").gsub(/[^a-z0-9]/, ' ').strip.gsub(/\s+/, ' ').gsub(/\s/, '-') : ''
  end

  def get_set_from_filename(filename)
    if filename.nil?
      '1'
    elsif filename[0...6] == '(Check)'
      'S'
    elsif filename[0..3] == 'II-e'
      'E'
    elsif filename[0..2] == 'III'
      '3'
    elsif filename[0..1] == 'II'
      '2'
    else
      '1'
    end
  end

  def valid?
    @filename.present? &&
      @_track.title.present? &&
      @_track.position.present? &&
      @_track.songs.to_a.present? &&
      @_track.set.present?
  end

  def to_s
    (!valid? ? '* ' : '  ') +
      format('%2d. [%1s] %-30.30s     %-30.30s     ', pos, @_track.set, @_track.title, @filename) +
      @_track.songs.map { |song| format('(%-3d) %-20.20s', song.id, song.title) }.join('   ')
  end

  def pos
    @_track.position
  end

  def decr_pos
    @_track.position -= 1
  end

  def incr_pos
    @_track.position += 1
  end

  def merge_track(track)
    @_track.title += " > #{track.title}"
    @_track.songs << track.songs.reject { |s| @_track.songs.include?(s) }
    @filename ||= track.filename
    true
  end

  def method_missing(method, *args, &_block)
    return @_track.send(method, *args) if @_track.respond_to?(method)
    super
  end

  def respond_to_missing?(method)
    @_track.respond_to?(method)
  end
end
