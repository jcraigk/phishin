# app/api/api_v2/admin/staging.rb
# Every edit in staging is a write to staged_tracks; the audio is untouched
# until commit. Each mutating endpoint answers with the full staging payload,
# because a split, combine or delete renumbers its neighbors and the editor
# would otherwise have to guess which rows moved.
class ApiV2::Admin::Staging < ApiV2::Admin::Base
  helpers ApiV2::Helpers::AdminHelper

  before { authenticate_admin! }

  DATE = { date: /\d{4}-\d{2}-\d{2}/ }.freeze

  namespace :admin do
    resource :shows do
      desc "Ingest a show into lossless staging", hidden: true
      params do
        optional :signed_ids, type: Array[String], default: []
        optional :archive_item, type: String
      end
      post ":date/ingest", requirements: DATE do
        show = admin_show
        error!({ message: "Show is already published" }, 422) if show.published?
        error!({ message: "Show already has tracks" }, 422) if show.tracks.exists?
        if params[:signed_ids].empty? && params[:archive_item].blank?
          error!({ message: "Upload files or give an archive.org item" }, 422)
        end
        job = AdminJob.create!(kind: "ingest", show:)
        Admin::IngestStagingJob.perform_async(show.id, job.id, params[:signed_ids], params[:archive_item].presence)
        status 201
        { job_id: job.id }
      end

      namespace ":date/staging", requirements: DATE do
        desc "Fetch the staging state", hidden: true
        get do
          staging_payload(admin_show) || error!({ message: "Nothing staged" }, 404)
        end

        desc "Update a staged track", hidden: true
        params do
          optional :title, type: String
          optional :set, type: String, values: StagedTrack::SETS
          optional :song_id, type: Integer
          optional :start_s, type: Float
          optional :end_s, type: Float
          optional :fade_in_s, type: Float
          optional :fade_out_s, type: Float
        end
        patch "tracks/:id" do
          track = staged_track
          updates = declared(params, include_missing: false).except(:date, :id).to_h.symbolize_keys
          updates[:song] = lookup_or_nil(Song, updates.delete(:song_id)) if updates.key?(:song_id)
          track.assign_attributes(updates)
          ensure_in_bounds!(track)
          save_or_422!(track)
          StagedTrack.renumber!(track.show) if updates.key?(:start_s)
          staging_payload(track.show.reload)
        end

        # The fade-out travels with the end of the track, so it goes to the
        # second half. Positions after the cut shift down by one.
        desc "Split a staged track at a time", hidden: true
        params do
          requires :at_s, type: Float
        end
        post "tracks/:id/split" do
          track = staged_track
          at = params[:at_s]
          unless at >= track.start_s + StagedTrack::MIN_LENGTH_S && at <= track.end_s - StagedTrack::MIN_LENGTH_S
            error!({ message: "cut must leave at least #{StagedTrack::MIN_LENGTH_S}s on each side" }, 422)
          end
          ActiveRecord::Base.transaction do
            second = track.show.staged_tracks.new(
              position: track.show.staged_tracks.maximum(:position) + 1, set: track.set,
              title: "#{track.title} (2)", song: track.song,
              start_s: at, end_s: track.end_s, fade_in_s: 0, fade_out_s: track.fade_out_s
            )
            track.update!(end_s: at, fade_out_s: 0)
            second.save!
            StagedTrack.renumber!(track.show)
          end
          staging_payload(track.show.reload)
        end

        desc "Combine a staged track with the next", hidden: true
        post "tracks/:id/combine" do
          track = staged_track
          following = track.next_track || error!({ message: "No track below to combine with" }, 422)
          ActiveRecord::Base.transaction do
            track.update!(end_s: following.end_s, fade_out_s: following.fade_out_s)
            following.destroy!
            StagedTrack.renumber!(track.show)
          end
          staging_payload(track.show.reload)
        end

        desc "Move the boundary between a staged track and the next", hidden: true
        params do
          requires :at_s, type: Float
        end
        put "tracks/:id/boundary" do
          track = staged_track
          following = track.next_track || error!({ message: "No track below to share a boundary with" }, 422)
          at = params[:at_s]
          low = track.start_s + StagedTrack::MIN_LENGTH_S
          high = following.end_s - StagedTrack::MIN_LENGTH_S
          error!({ message: "boundary must be between #{low}s and #{high}s" }, 422) unless at >= low && at <= high
          ActiveRecord::Base.transaction do
            track.update!(end_s: at)
            following.update!(start_s: at)
          end
          staging_payload(track.show.reload)
        end

        desc "Remove a staged track", hidden: true
        delete "tracks/:id" do
          track = staged_track
          ActiveRecord::Base.transaction do
            track.destroy!
            StagedTrack.renumber!(track.show)
          end
          staging_payload(track.show.reload)
        end

        desc "Stream a source's preview audio", hidden: true
        get "sources/:id/audio" do
          show = admin_show
          source = show.staged_sources.find(params[:id])
          path = Admin::StagingDir.new(show).proxy_path(source)
          error!({ message: "No preview audio" }, 404) unless File.exist?(path)
          content_type "audio/mpeg"
          header "Content-Length", File.size(path).to_s
          header "Accept-Ranges", "none"
          env["api.format"] = :binary
          body File.binread(path)
        end

        desc "Commit staging to tracks", hidden: true
        post "commit" do
          show = admin_show
          error!({ message: "Nothing staged" }, 422) unless show.staged_tracks.exists?
          error!({ message: "Show is already published" }, 422) if show.published?
          job = AdminJob.create!(kind: "commit_staging", show:)
          Admin::CommitStagingJob.perform_async(show.id, job.id)
          status 201
          { job_id: job.id }
        end

        desc "Discard staging", hidden: true
        delete do
          show = admin_show
          show.tracks.destroy_all unless show.published?
          show.staged_tracks.destroy_all
          show.staged_sources.destroy_all
          show.update!(staging_source_url: nil)
          Admin::StagingDir.new(show).remove!
          status 204
          body false
        end
      end
    end
  end

  helpers do
    def staged_track
      admin_show.staged_tracks.find(params[:id])
    end

    def lookup_or_nil(klass, id)
      id.nil? ? nil : klass.find(id)
    end

    # Neighbors are checked here rather than in the model so the message can
    # name what was hit. Trimming inward (a gap between tracks) is allowed: it
    # is how the head of a show or a between-set tape flip gets dropped.
    def ensure_in_bounds!(track)
      total = track.show.staged_sources.sum(:duration_s)
      error!({ message: "start must not be before the timeline" }, 422) if track.start_s.negative?
      error!({ message: "end must not be past the timeline (#{total}s)" }, 422) if track.end_s > total
      if (prev = track.previous_track) && track.start_s < prev.end_s
        error!({ message: "start would overlap #{prev.title}" }, 422)
      end
      if (following = track.next_track) && track.end_s > following.start_s
        error!({ message: "end would overlap #{following.title}" }, 422)
      end
    end

    def save_or_422!(record)
      return if record.save
      error!({ message: record.errors.full_messages.join(", ") }, 422)
    end
  end
end
