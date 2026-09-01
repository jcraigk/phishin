class Admin::ReplaceAudioJob
  include Sidekiq::Job
  include LameEncoding

  class Error < StandardError; end

  def perform(track_id, admin_job_id, signed_id)
    @track = Track.find(track_id)
    admin_job = AdminJob.find(admin_job_id)

    admin_job.run! do
      blob = mp3_blob(ActiveStorage::Blob.find_signed!(signed_id))
      backup_path = TrackAudioReplacer.call(
        track: @track, blob:, operation: "replace_audio", admin_job:
      )
      admin_job.payload["backup_path"] = backup_path if backup_path
      admin_job.save!
    end
  end

  private

  def mp3_blob(blob)
    filename = Show.original_filename(blob).to_s
    return blob if File.extname(filename).downcase == ".mp3"

    Dir.mktmpdir("replace_audio") do |dir|
      src = File.join(dir, File.basename(filename))
      File.open(src, "wb") { |file| blob.download { |chunk| file.write(chunk) } }
      out = File.join(dir, "#{SecureRandom.hex(4)}.mp3")
      render_via_lame(out, [ "-i", src ])
      converted = ActiveStorage::Blob.create_and_upload!(
        io: File.open(out),
        filename: "#{File.basename(filename, '.*')}.mp3",
        content_type: "audio/mpeg"
      )
      blob.purge
      converted
    end
  end

  def label
    @track.title
  end
end
