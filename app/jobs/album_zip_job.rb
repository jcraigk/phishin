require "zip"

class AlbumZipJob
  include Sidekiq::Job

  attr_reader :show_id

  def perform(show_id)
    @show_id = show_id

    AlbumZipCleanupJob.new.perform

    create_and_attach_album_zip
    show.update!(album_zip_requested_at: nil)
  end

  private

  def create_and_attach_album_zip
    Tempfile.open([ "album-zip-#{show_id}", ".zip" ]) do |temp_zip| # rubocop:disable Metrics/BlockLength
      Zip::File.open(temp_zip.path, Zip::File::CREATE) do |zipfile|
        # Tracks
        show.tracks.order(:position).each do |track|
          track_filename = "#{format("%02d", track.position)} #{sanitize(track.title)}.mp3"
          zipfile.get_output_stream(track_filename) do |stream|
            stream.write track.mp3_audio.download
          end
        end

        # taper_notes.txt
        zipfile.get_output_stream("taper_notes.txt") do |stream|
          stream.write "#{show.taper_notes}\n\n=== Downloaded from https://phish.in ==="
        end

        # cover_art.jpg
        if show.cover_art.attached? && show.cover_art
          zipfile.get_output_stream("cover_art.jpg") do |stream|
            stream.write show.cover_art.download
          end
        end

        # album_cover.jpg
        if show.album_cover.attached?
          zipfile.get_output_stream("album_cover.jpg") do |stream|
            stream.write show.album_cover.download
          end
        end
      end

      show.album_zip.attach \
        io: File.open(temp_zip.path),
        filename: "Phish #{show.date} MP3.zip",
        content_type: "application/zip"
    end
  end

  def sanitize(str)
    str.gsub(/[\/\\<>:"|?*]/, " ").gsub(",", " ").squeeze(" ").strip
  end

  def show
    @show ||= Show.find(show_id)
  end
end
