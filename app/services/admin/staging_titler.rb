class Admin::StagingTitler
  def self.call(show:, sources:, notes: nil)
    new(show:, sources:, notes:).call
  end

  def initialize(show:, sources:, notes: nil)
    @show = show
    @sources = sources
    @notes = notes
    @used = []
  end

  def call
    return by_position if setlist && setlist.size == @sources.size
    by_filename
  end

  private

  def setlist
    return @setlist if defined?(@setlist)
    @setlist = match&.tracks
  end

  def match
    @match ||= ShowImporter::Matcher.call(
      date: @show.date.to_s, filenames: @sources.map { as_mp3(it.filename) }
    )
  rescue ShowImporter::ShowInfo::NotFoundError
    nil
  end

  def by_position
    setlist.map { |t| { title: t[:title], set: t[:set].presence || "1", song_ids: [ t[:song_id] ].compact } }
  end

  def by_filename
    matched = (setlist || []).select { it[:filename] }.index_by { it[:filename] }
    @used.concat(matched.values)
    set = "1"
    @sources.map do |source|
      hit = matched[as_mp3(source.filename)]
      guess = (hit && from_setlist(hit, set)) || from_notes(source, set) ||
              { title: File.basename(source.filename, ".*"), set:, song_ids: [] }
      set = guess[:set]
      guess
    end
  end

  def from_setlist(entry, set)
    { title: entry[:title], set: entry[:set].presence || set, song_ids: [ entry[:song_id] ].compact }
  end

  def from_notes(source, set)
    title = notes_titles[source.filename]
    return if title.blank?
    entry = (setlist || []).find { !@used.include?(it) && it[:title].casecmp?(title) }
    if entry
      @used << entry
      return from_setlist(entry, set)
    end
    song = Song.where("lower(title) = ?", title.downcase).first
    { title: song&.title || title, set:, song_ids: [ song&.id ].compact }
  end

  def notes_titles
    @notes_titles ||= Admin::TaperNotesTitles.call(notes: @notes, filenames: @sources.map(&:filename))
  end

  def as_mp3(filename)
    "#{File.basename(filename, '.*')}.mp3"
  end
end
