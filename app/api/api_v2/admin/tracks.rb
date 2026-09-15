class ApiV2::Admin::Tracks < ApiV2::Admin::Base
  VALID_SETS = %w[S 1 2 3 4 E E2 E3].freeze

  helpers ApiV2::Helpers::AdminHelper

  before { authenticate_admin! }

  namespace :admin do
    resource :tracks do
      desc "Update a track", hidden: true
      params do
        optional :title, type: String
        optional :slug, type: String, regexp: /\A[a-z0-9]+(-[a-z0-9]+)*\z/
        optional :set, type: String, values: VALID_SETS
        optional :song_ids, type: Array[Integer]
        optional :jam_starts_at_second, type: Integer
        optional :exclude_from_stats, type: Boolean
      end
      patch ":id" do
        track = Track.find(params[:id])
        updates = declared(params, include_missing: false).except(:id).symbolize_keys

        ActiveRecord::Base.transaction do
          if updates.key?(:song_ids)
            track.songs = Song.where(id: updates.delete(:song_ids))
          end

          if updates.key?(:title) && !track.show.published? && !updates.key?(:slug)
            track.title = updates.delete(:title)
            track.generate_slug(force: true)
          end

          track.update!(updates)
        end

        track_payload(track.reload)
      end

      desc "Render both sides of a moved boundary without altering either track",
           hidden: true
      params { use :shift_boundary_params }
      post ":id/shift_boundary_preview" do
        enqueue_shift_boundary("shift_boundary_preview", false)
      end

      desc "Move the boundary between this track and the next", hidden: true
      params { use :shift_boundary_params }
      post ":id/shift_boundary_apply" do
        enqueue_shift_boundary("shift_boundary_apply", true)
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

      desc "Replace a track's audio file", hidden: true
      params { requires :signed_id, type: String }
      post ":id/replace_audio" do
        track = Track.find(params[:id])
        enqueue_job("replace_audio", Admin::ReplaceAudioJob, show: track.show, track:, args: [ params[:signed_id] ])
      end

      desc "Delete a track", hidden: true
      delete ":id" do
        track = Track.find(params[:id])
        show = track.show
        ActiveRecord::Base.transaction do
          track.destroy!
          show.renumber_tracks!
        end
        editor_payload(show.reload)
      end
    end
  end

  helpers do
    def enqueue_trim(kind, apply)
      track = Track.find(params[:id])
      error!({ message: "Track has no audio" }, 422) unless track.mp3_audio.attached?
      opts = declared(params, include_missing: false)
             .slice(:trim_start, :trim_end, :fade_in, :fade_out, :tail_pad).to_json
      enqueue_job(kind, Admin::TrimJob, show: track.show, track:, args: [ opts, apply ])
    end

    def enqueue_shift_boundary(kind, apply)
      track = Track.find(params[:id])
      following = track.show.tracks.find_by(position: track.position + 1)
      error!({ message: "No following track to share a boundary with" }, 422) if following.nil?
      unless track.mp3_audio.attached? && following.mp3_audio.attached?
        error!({ message: "Both tracks need audio to shift the boundary" }, 422)
      end
      ensure_delta_in_range!(track, following)
      enqueue_job(kind, Admin::ShiftBoundaryJob, show: track.show, track:, args: [ params[:delta_s], apply ])
    end

    def ensure_delta_in_range!(track, following)
      min = Admin::ShiftBoundaryJob::MIN_PART_S
      low = (min - track.duration.to_i / 1000.0).round(1)
      high = (following.duration.to_i / 1000.0 - min).round(1)
      return if params[:delta_s] >= low && params[:delta_s] <= high
      error!(
        { message: "Boundary shift must be between #{low}s and #{high}s" },
        422
      )
    end
  end
end
