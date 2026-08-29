# First-guess titles for freshly ingested sources. An admin corrects these in
# the staging editor, so the goal is a good start, not certainty.
#
# archive.org sets are almost always one file per setlist song, so when the
# counts agree the setlist is applied in order. Otherwise the importer's
# filename matcher gets a turn (it recognizes "I 01 Buried Alive" style names),
# and anything still unmatched is titled after its file.
class Admin::StagingTitler
  def self.call(show:, sources:)
    new(show:, sources:).call
  end

  def initialize(show:, sources:)
    @show = show
    @sources = sources
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

  # Filenames are handed over with an mp3 extension because FilenameMatcher
  # scrubs exactly that suffix before searching song titles.
  def match
    @match ||= ShowImporter::Matcher.call(
      date: @show.date.to_s, filenames: @sources.map { as_mp3(it.filename) }
    ).tap(&:tracks)
  rescue ShowImporter::ShowInfo::NotFoundError
    nil
  end

  def by_position
    setlist.map { |t| { title: t[:title], set: t[:set].presence || "1", song_id: t[:song_id] } }
  end

  def by_filename
    matched = (setlist || []).select { it[:filename] }.index_by { it[:filename] }
    @sources.map do |source|
      hit = matched[as_mp3(source.filename)]
      if hit
        { title: hit[:title], set: hit[:set].presence || "1", song_id: hit[:song_id] }
      else
        { title: File.basename(source.filename, ".*"), set: "1", song_id: nil }
      end
    end
  end

  def as_mp3(filename)
    "#{File.basename(filename, '.*')}.mp3"
  end
end
