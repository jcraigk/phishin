class ApiV2::Admin::Staging < ApiV2::Admin::Base
  helpers ApiV2::Helpers::AdminHelper

  before { authenticate_admin! }

  EDGE_TOLERANCE_S = 0.002

  namespace :admin do
    resource :shows do
      desc "Ingest an archive.org item, deriving the show date from it", hidden: true
      params do
        requires :url, type: String
      end
      post "archive_import" do
        item = Admin::ArchiveItem.new(params[:url])
        error!({ message: "Could not find a date on that archive.org item" }, 422) if item.date.blank?
        start_ingest(item.date, archive_item: item.identifier)
      rescue Admin::ArchiveItem::NotFoundError, ArgumentError => e
        error!({ message: e.message }, 422)
      end

      desc "Ingest uploaded files, deriving the show date from them", hidden: true
      params do
        requires :signed_ids, type: Array[String]
      end
      post "upload_import" do
        error!({ message: "Upload at least one file" }, 422) if params[:signed_ids].empty?
        blobs = params[:signed_ids].map { find_signed_blob(it) }
        date = Admin::UploadDateSniffer.call(blobs)
        if date.blank?
          error!({ message: "Could not find a show date in the upload; include taper notes with the date" }, 422)
        end
        start_ingest(date, signed_ids: params[:signed_ids])
      end

      namespace ":date/staging", requirements: DATE do
        desc "Update a staged track", hidden: true
        params do
          optional :title, type: String
          optional :set, type: String, values: StagedTrack::SETS
          optional :song_ids, type: Array[Integer]
          optional :start_s, type: Float
          optional :end_s, type: Float
          optional :fade_in_s, type: Float
          optional :fade_out_s, type: Float
        end
        patch "tracks/:id" do
          track = staged_track
          updates = declared(params, include_missing: false).except(:date, :id).to_h.symbolize_keys
          updates[:song_ids] = existing_song_ids(updates[:song_ids]) if updates.key?(:song_ids)
          track.assign_attributes(updates)
          ensure_in_bounds!(track) if updates.key?(:start_s) || updates.key?(:end_s)
          ensure_sets_in_order!(track.show, { track.id => track.set }) if updates.key?(:set)
          save_or_422!(track)
          StagedTrack.renumber!(track.show) if updates.key?(:start_s)
          StagedTrack.normalize_edge_fades!(track.show) if updates.key?(:set)
          staging_payload(track.show.reload)
        end

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
              title: "#{track.title} (2)", song_ids: track.song_ids,
              start_s: at, end_s: track.end_s, fade_in_s: 0, fade_out_s: track.fade_out_s,
              original_start_s: at, original_end_s: track.original_end_s
            )
            track.update!(end_s: at, fade_out_s: 0, original_end_s: at, combines: [])
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
            track.update!(
              title: "#{track.title} > #{following.title}", song_ids: (track.song_ids + following.song_ids).uniq,
              end_s: following.end_s, fade_out_s: following.fade_out_s, original_end_s: following.original_end_s,
              combines: track.combines + [ combine_record(track, following) ]
            )
            following.destroy!
            StagedTrack.renumber!(track.show)
          end
          staging_payload(track.show.reload)
        end

        desc "Undo the last combine on a staged track", hidden: true
        post "tracks/:id/uncombine" do
          track = staged_track
          record = track.combines.last || error!({ message: "Nothing to undo" }, 422)
          seam = record["end_s"]
          unless seam >= track.start_s + StagedTrack::MIN_LENGTH_S && seam <= track.end_s - StagedTrack::MIN_LENGTH_S
            error!({ message: "The old seam is no longer inside this track" }, 422)
          end
          restored = record["following"]
          ActiveRecord::Base.transaction do
            following = track.show.staged_tracks.new(
              position: track.show.staged_tracks.maximum(:position) + 1, set: track.set,
              title: restored["title"], song_ids: restored["song_ids"],
              start_s: seam, end_s: track.end_s, fade_out_s: track.fade_out_s,
              original_start_s: restored["original_start_s"], original_end_s: track.original_end_s,
              combines: restored["combines"]
            )
            track.update!(
              title: record["title"], song_ids: record["song_ids"], end_s: seam, fade_out_s: 0,
              original_end_s: record["original_end_s"], combines: track.combines[0...-1]
            )
            following.save!
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

        desc "Waveform peaks for the whole staged timeline", hidden: true
        get "peaks" do
          path = Admin::StagingDir.new(admin_show).peaks
          error!({ message: "No waveform" }, 404) unless File.exist?(path)
          content_type "application/octet-stream"
          header "Content-Length", File.size(path).to_s
          header "X-Peaks-Rate", Admin::StagingPeaks::RATE.to_s
          env["api.format"] = :binary
          body File.binread(path)
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
          error!({ message: "Choose a venue before committing" }, 422) if show.venue.nil?
          songless = show.staged_tracks.ordered.select { it.song_ids.empty? }
          if songless.any?
            error!({ message: "Every track needs a song: #{songless.map(&:title).join(', ')}" }, 422)
          end
          enqueue_job("commit_staging", Admin::CommitStagingJob, show:)
        end

        desc "Discard staging", hidden: true
        delete do
          show = admin_show
          show.tracks.destroy_all unless show.published?
          show.discard_staging!
          status 204
          body false
        end
      end
    end
  end

  helpers do
    def start_ingest(date, signed_ids: [], archive_item: nil)
      show = Show.find_by(date:)
      created = show.nil?
      show ||= Show.create_draft!(date)
      ensure_draft_without_tracks!(show)
      enqueue_job("ingest", Admin::IngestStagingJob, show:, args: [ signed_ids, archive_item, created ])
        .merge(date: show.date.iso8601)
    end

    def staged_track
      admin_show.staged_tracks.find(params[:id])
    end

    def combine_record(track, following)
      {
        title: track.title, song_ids: track.song_ids, end_s: track.end_s.to_f, original_end_s: track.original_end_s&.to_f,
        following: {
          title: following.title, song_ids: following.song_ids,
          original_start_s: following.original_start_s&.to_f, combines: following.combines
        }
      }
    end

    def existing_song_ids(ids)
      found = Song.where(id: ids).pluck(:id)
      ids.select { found.include?(it) }
    end

    def ensure_in_bounds!(track)
      total = track.show.staged_sources.sum(:duration_s)
      error!({ message: "start must not be before the timeline" }, 422) if track.start_s.negative?
      error!({ message: "end must not be past the timeline (#{total}s)" }, 422) if track.end_s > total
      if (prev = track.previous_track) && track.start_s < prev.end_s - EDGE_TOLERANCE_S
        error!({ message: "start would overlap #{prev.title}" }, 422)
      end
      if (following = track.next_track) && track.end_s > following.start_s + EDGE_TOLERANCE_S
        error!({ message: "end would overlap #{following.title}" }, 422)
      end
    end

    def ensure_sets_in_order!(show, overrides)
      sets = show.staged_tracks.order(:position).map { |t| overrides.fetch(t.id, t.set) }
      return if sets.each_cons(2).all? { |a, b| StagedTrack.rank(a) <= StagedTrack.rank(b) }
      error!({ message: "Sets must stay in order along the show" }, 422)
    end

    def save_or_422!(record)
      return if record.save
      error!({ message: record.errors.full_messages.join(", ") }, 422)
    end
  end
end
