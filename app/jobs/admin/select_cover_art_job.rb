class Admin::SelectCoverArtJob
  include Sidekiq::Job

  ATTACH_PROGRESS = 10
  ALBUM_COVER_PROGRESS = 20
  ID3_PROGRESS_SHARE = 60

  def perform(show_id, admin_job_id, blob_key, zoom = 0)
    @show = Show.find(show_id)
    @admin_job = AdminJob.find(admin_job_id)
    @failures = []

    @admin_job.run! do
      blob = candidate_blob(blob_key)
      attach_cover_art(blob, zoom.to_i)
      commit_prompt_snapshot(blob)
      build_album_cover
      embed_id3_tags
      propagate_to_children
      clear_candidates(blob)
      finalize
    end
  end

  private

  def candidate_blob(blob_key)
    attachment = @show.cover_art_candidates_attachments.includes(:blob)
                      .find { |candidate| candidate.blob.key == blob_key }
    raise "Unknown cover art candidate: #{blob_key}" if attachment.nil?
    attachment.blob
  end

  def attach_cover_art(blob, zoom)
    if zoom.positive?
      attach_zoomed(blob, zoom)
    else
      @show.cover_art.attach(blob)
    end
    @admin_job.update!(progress: ATTACH_PROGRESS, message: "Applied cover art")
  end

  def attach_zoomed(blob, zoom)
    Tempfile.create([ "cover_art_source", File.extname(blob.filename.to_s) ]) do |file|
      file.binmode
      blob.download { |chunk| file.write(chunk) }
      file.flush
      @show.attach_cover_art_by_path(file.path, zoom:)
    end
  end

  def commit_prompt_snapshot(blob)
    base = blob.metadata["prompt"]
    return if base.blank?
    edits = Array(blob.metadata["edits"]).map { |edit| "edit: #{edit}" }
    @show.update!(cover_art_prompt: ([ base ] + edits).join(" | "))
  end

  def build_album_cover
    AlbumCoverService.call(@show)
    @admin_job.update!(progress: ALBUM_COVER_PROGRESS, message: "Composited album cover")
  end

  def embed_id3_tags
    tracks = @show.tracks.order(:position).to_a
    tracks.each_with_index do |track, index|
      embed_track(track)
      report_id3_progress(index + 1, tracks.size)
    end
  end

  def embed_track(track)
    track.apply_id3_tags
  rescue StandardError => e
    @failures << { "track_id" => track.id, "title" => track.title, "error" => e.message }
  end

  def report_id3_progress(done, total)
    return if total.zero?
    share = (done * ID3_PROGRESS_SHARE.to_f / total).round
    @admin_job.update!(
      progress: ALBUM_COVER_PROGRESS + share,
      message: "Embedded album art on #{done} of #{total} tracks"
    )
  end

  def propagate_to_children
    children = Show.where(cover_art_parent_show_id: @show.id).order(date: :asc)
    children.each do |child|
      child.cover_art.attach(@show.cover_art.blob)
      AlbumCoverService.call(child)
      child.tracks.order(:position).each { |track| embed_track(track) }
      @admin_job.update!(message: "Propagated cover art to #{child.date}")
    end
  end

  def clear_candidates(winner_blob)
    @show.cover_art_candidates_attachments.reload.each do |attachment|
      blob = attachment.blob
      attachment.destroy
      next if blob.id == winner_blob.id
      purge_if_unreferenced(blob)
    end
  end

  def purge_if_unreferenced(blob)
    return if ActiveStorage::Attachment.where(blob_id: blob.id).exists?
    blob.purge
  end

  def finalize
    @admin_job.payload["failed_tracks"] = @failures
    @admin_job.save!
    return if @failures.empty?
    @admin_job.update!(message: "Cover art applied, #{@failures.size} track(s) failed ID3")
  end
end
