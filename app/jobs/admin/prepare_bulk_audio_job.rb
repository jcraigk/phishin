class Admin::PrepareBulkAudioJob
  include Sidekiq::Job
  include LameEncoding

  class Error < StandardError; end
  class NoAudioError < Error; end

  def perform(show_id, admin_job_id, signed_ids)
    @show = Show.find(show_id)
    @admin_job = AdminJob.find(admin_job_id)

    @admin_job.run! do
      Dir.mktmpdir("bulk_audio_prepare") do |dir|
        @intake = Admin::UploadIntake.new(dir).receive(signed_ids)
        files = @intake.audio_files
        raise NoAudioError, "no audio files found in the upload" if files.empty?
        titles = titles_for(files)
        ids = files.map.with_index do |path, index|
          @admin_job.update!(
            progress: (index * 100.0 / files.size).round,
            message: "Preparing #{File.basename(path)}"
          )
          upload_as_mp3(path, titles[path]).signed_id
        end
        @admin_job.update!(
          message: "Prepared #{files.size} files",
          payload: @admin_job.payload.merge("signed_ids" => ids)
        )
      end
    end
  end

  private

  def uploaded_notes
    @uploaded_notes ||= @intake.notes_text
  end

  def titles_for(files)
    notes = uploaded_notes.presence || @show.taper_notes.to_s
    @show.update!(taper_notes: notes) if uploaded_notes.present? && @show.taper_notes.blank?
    by_name = Admin::TaperNotesTitles.call(notes:, filenames: files.map { File.basename(it) })
    files.index_with { by_name[File.basename(it)]&.tr("/", "-") }
  end

  def upload_as_mp3(path, title)
    mp3_blob_from_path(path, filename: "#{title || embedded_title(path) || File.basename(path, '.*')}.mp3")
  end

  def embedded_title(path)
    Admin::AudioProbe.read(path, "format_tags=title")&.tr("/", "-").presence
  end

  def label
    @show.date.to_s
  end
end
