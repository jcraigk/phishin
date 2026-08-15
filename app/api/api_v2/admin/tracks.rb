class ApiV2::Admin::Tracks < ApiV2::Admin::Base
  VALID_SETS = %w[S 1 2 3 4 E E2 E3].freeze

  helpers ApiV2::Helpers::AdminHelper

  before { authenticate_admin! }

  namespace :admin do
    resource :tracks do
      desc "Update a track", hidden: true
      params do
        optional :title, type: String
        optional :set, type: String, values: VALID_SETS
        optional :song_ids, type: Array[Integer]
        optional :jam_starts_at_second, type: Integer
        optional :exclude_from_stats, type: Boolean
        optional :staged_attachment_id, type: Integer
      end
      patch ":id" do
        track = Track.find(params[:id])
        updates = declared(params, include_missing: false).except(:id).symbolize_keys

        ActiveRecord::Base.transaction do
          if updates.key?(:song_ids)
            track.songs = Song.where(id: updates.delete(:song_ids))
          end

          attachment_id = updates.delete(:staged_attachment_id)

          # A published show keeps its slug so existing track URLs stay valid.
          if updates.key?(:title) && !track.show.published?
            track.title = updates.delete(:title)
            track.generate_slug(force: true)
          end

          track.update!(updates)
          attach_staged_audio(track, attachment_id) if attachment_id
        end

        track_payload(track.reload)
      end

      desc "Render a combine preview without altering either track", hidden: true
      post ":id/combine_preview" do
        enqueue_combine("combine_preview", false)
      end

      desc "Merge a track into the previous track", hidden: true
      post ":id/combine_apply" do
        enqueue_combine("combine_apply", true)
      end

      desc "Render a trim preview without altering the track", hidden: true
      params { use :trim_params }
      post ":id/trim_preview" do
        enqueue_trim("trim_preview", false)
      end

      desc "Apply a trim to the track's audio", hidden: true
      params { use :trim_params }
      post ":id/trim_apply" do
        enqueue_trim("trim_apply", true)
      end

      desc "Render a split preview without altering the track", hidden: true
      params { requires :cut_s, type: Float }
      post ":id/split_preview" do
        enqueue_split("split_preview", false)
      end

      desc "Split the track into two at the cut point", hidden: true
      params { requires :cut_s, type: Float }
      post ":id/split_apply" do
        enqueue_split("split_apply", true)
      end

      desc "Replace a track's audio file", hidden: true
      params { requires :signed_id, type: String }
      post ":id/replace_audio" do
        track = Track.find(params[:id])
        job = AdminJob.create!(kind: "replace_audio", track:, show: track.show)
        Admin::ReplaceAudioJob.perform_async(track.id, job.id, params[:signed_id])
        status 201
        { job_id: job.id }
      end

      desc "Delete a track", hidden: true
      delete ":id" do
        track = Track.find(params[:id])
        show = track.show
        ActiveRecord::Base.transaction do
          track.destroy!
          renumber(show)
        end
        editor_payload(show.reload)
      end
    end
  end

  helpers do
    # Preview and apply differ only in the dry_run flag handed to the job, so both
    # audition and commit run the same render through the same service.
    def enqueue_trim(kind, apply)
      track = Track.find(params[:id])
      error!({ message: "Track has no audio" }, 422) unless track.mp3_audio.attached?
      job = AdminJob.create!(kind:, track:, show: track.show)
      opts = declared(params, include_missing: false)
             .slice(:trim_start, :trim_end, :fade_in, :fade_out).to_json
      Admin::TrimJob.perform_async(track.id, job.id, opts, apply)
      status 201
      { job_id: job.id }
    end

    # Same shape as enqueue_trim: preview and apply differ only in the flag the job
    # hands the service. The title check mirrors TrackSplitService's own so a segue
    # the service would accept is never rejected here, and an obviously unsplittable
    # title fails at the click rather than in a background job.
    def enqueue_split(kind, apply)
      track = Track.find(params[:id])
      error!({ message: "Track has no audio" }, 422) unless track.mp3_audio.attached?
      unless track.title.count(">") == 1
        error!({ message: "Title needs exactly one '>' to split" }, 422)
      end
      job = AdminJob.create!(kind:, track:, show: track.show)
      Admin::SplitJob.perform_async(track.id, job.id, params[:cut_s], apply)
      status 201
      { job_id: job.id }
    end

    # Combining replaced an inline endpoint that merged metadata in the request
    # and threw the second track's audio away. Joining two files is an ffmpeg
    # render, so it runs as a job on the preview-then-apply pattern trim and
    # split use, and the preview lets an admin hear the seam before a track row
    # is destroyed. The missing-previous check runs here so the first track in a
    # show fails at the click rather than in a background job.
    def enqueue_combine(kind, apply)
      track = Track.find(params[:id])
      previous = track.show.tracks.find_by(position: track.position - 1)
      error!({ message: "No previous track to combine into" }, 422) if previous.nil?
      job = AdminJob.create!(kind:, track:, show: track.show)
      Admin::CombineTracksJob.perform_async(track.id, job.id, apply)
      status 201
      { job_id: job.id }
    end

    def attach_staged_audio(track, attachment_id)
      attachment = track.show.staged_audio_attachments.find(attachment_id)
      track.mp3_audio.attach(attachment.blob)
      track.update!(audio_status: "complete")
      track.process_mp3_audio
    end

    # Position is unique per show, so the first pass parks every row in the negative
    # mirror of its target (a range no real row occupies) and the second flips them
    # positive. update_columns bypasses validations, which is what makes the parking
    # state legal. Callers today only ever compact downward after a destroy, which a
    # single ascending pass would survive, but this stays correct for any target order.
    def renumber(show)
      show.tracks.order(:position).each.with_index(1) do |track, index|
        track.update_columns(position: -index)
      end
      show.tracks.where(position: ...0).each do |track|
        track.update_columns(position: -track.position)
      end
    end
  end
end
