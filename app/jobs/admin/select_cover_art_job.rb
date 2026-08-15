# Promotes one cover art candidate to be the show's actual cover art, then walks
# the rest of the pipeline the CLI runs by hand: composite the album cover, push
# the new art into every track's ID3 tags, hand it down to parent-linked child
# shows, and drop the candidates the admin passed over.
#
# Blob ownership is the delicate part. A candidate blob can be shared -- a
# parent-linked show is offered its parent's own cover art blob as a candidate --
# so nothing here purges a blob that another attachment still points at. Losing
# candidates give up their attachment first and their blob only if that was the
# last reference. Variant records are never touched: replacing an attachment lets
# Active Storage retire the old blob and its variants together, while destroying
# variant records by hand is what orphans them and silently breaks album art
# embedding.
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
      build_album_cover
      embed_id3_tags
      propagate_to_children
      clear_candidates(blob)
      finalize
    end
  end

  private

  # The key must name an image this show already holds. An arbitrary key would
  # let a caller install any file in storage as the show's cover art.
  def candidate_blob(blob_key)
    attachment = @show.cover_art_candidates_attachments.includes(:blob)
                      .find { |candidate| candidate.blob.key == blob_key }
    raise "Unknown cover art candidate: #{blob_key}" if attachment.nil?
    attachment.blob
  end

  # Zoom reuses HasCoverArt#attach_cover_art_by_path, the same crop-and-resize the
  # CLI drives, so a zoomed selection lands on a freshly processed blob. Without
  # zoom the candidate blob is attached as-is and the two attachments share it.
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

  def build_album_cover
    AlbumCoverService.call(@show)
    @admin_job.update!(progress: ALBUM_COVER_PROGRESS, message: "Composited album cover")
  end

  # One track's ID3 rewrite failing must not cost the admin the rest of the show:
  # the same isolation Admin::BulkReplaceAudioJob uses. Every track is
  # independent, a partial re-embed is still an improvement over none, and the
  # skipped tracks are named on the payload so the admin can retry them.
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

  # Children of a run share the parent's image, so they take the blob itself
  # rather than a copy. Attaching directly rather than through CoverArtImageService
  # keeps a child with a broken parent link from reaching the billed image API.
  def propagate_to_children
    children = Show.where(cover_art_parent_show_id: @show.id).order(date: :asc)
    children.each do |child|
      child.cover_art.attach(@show.cover_art.blob)
      AlbumCoverService.call(child)
      child.tracks.order(:position).each { |track| embed_track(track) }
      @admin_job.update!(message: "Propagated cover art to #{child.date}")
    end
  end

  # The winner keeps its blob: it is now the cover art (or, when zoomed, the
  # source the processed copy came from and possibly another show's art). Losers
  # give up their attachment, and their blob only when no other attachment is
  # left pointing at it.
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
