class ShowImporter::TrackReplacer
  attr_reader :date, :track_hash

  def initialize(date)
    @date = date
    @show = Show.find_by(date:)
    @track_hash = match_files_to_tracks

    ensure_tracks_present
    ensure_all_tracks_matched

    replace_audio_on_tracks if prompt_for_replacement == "Y"
  end

  def match_files_to_tracks
    filenames.each_with_object({}) do |filename, track_hash|
      tracks_kinda_matching(filename).each do |track|
        next if track_hash.value?(track) # Handle multiple instances of song
        break track_hash[filename] = track
      end
    end
  end

  private

  def prompt_for_replacement
    print "#{question} "
    gets.strip.upcase
  end

  def question
    "❓ #{date} already imported, replace track data? [Y/n]"
  end

  def tracks_kinda_matching(filename)
    Track.where(show_id: show.id)
         .kinda_matching(scrub_filename(filename))
         .order(position: :asc)
  end

  def replace_audio_on_tracks
    pbar = ProgressBar.create(total: track_hash.size, format: "%a %B %c/%C %p%% %E")

    track_hash.sort_by { |_k, v| v.position }
              .each do |filename, track|
      track.mp3_audio.attach(io: File.open(filename), filename: File.basename(filename))
      pbar.increment
    end
    pbar.finish

    show.save_duration
    clear_rails_cache
  end

  def ensure_tracks_present
    return unless nil_tracks.any?
    abort "❌ #{@show.date} => Not all files matched: #{nil_tracks.keys}"
  end

  def nil_tracks
    track_hash.select { |_k, v| v.nil? }
  end

  def ensure_all_tracks_matched
    return if unmatched_tracks.empty?
    abort "❌ #{@show.date} => Not all tracks matched: #{unmatched_tracks}"
  end

  def unmatched_tracks
    @unmatched_tracks ||= show.track_ids - track_hash.values.map(&:id)
  end

  def scrub_filename(filename)
    return "555" if /555/i.match?(filename)
    return "Mike's Song" if /mike/i.match?(filename)
    return "Free Bird" if /Freebird.mp3/.match?(filename)
    filename
      .gsub(".mp3", "")
      .gsub(/\AII?/, "")
      .tr("_", " ")
      .gsub(/\d/, "")
      .strip
  end

  def show
    @show ||= Show.find_by(date:)
  end

  def base_path
    @base_path ||= "#{App.content_import_path}/#{date}"
  end

  def filenames
    @filenames ||= Dir.glob("#{base_path}/*.mp3")
  end

  def clear_rails_cache
    Rails.cache.clear
  end
end
