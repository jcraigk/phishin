class ApiV2::Admin::Shows < ApiV2::Admin::Base
  helpers ApiV2::Helpers::AdminHelper

  before { authenticate_admin! }

  namespace :admin do
    resource :shows do
      desc "List shows for admin", hidden: true
      params do
        optional :published, type: Boolean, desc: "Filter by published state"
        optional :year, type: Integer, values: 1983..2100, desc: "Only shows in this year"
      end
      get do
        shows = Show.order(date: :desc).includes(:tags, :venue, :staged_sources, cover_art_attachment: :blob)
        shows = shows.where(published: params[:published]) unless params[:published].nil?
        shows = shows.during_year(params[:year]) if params[:year]
        {
          shows: shows.limit(500).map { |show| show_summary(show) }
        }
      end

      desc "Fetch a show for editing", hidden: true
      get ":date", requirements: DATE do
        editor_payload(admin_show)
      end

      desc "Publish readiness check", hidden: true
      get ":date/readiness", requirements: DATE do
        Admin::ShowReadiness.call(admin_show)
      end

      desc "Publish a draft show", hidden: true
      post ":date/publish", requirements: DATE do
        show = admin_show
        error!({ message: "Show is already published" }, 422) if show.published?
        readiness = Admin::ShowReadiness.call(show)
        unless readiness[:ready]
          error!({ message: "Not ready to publish", issues: readiness[:issues] }, 422)
        end
        enqueue_job("publish", Admin::PublishShowJob, show:)
      end

      desc "Recompute gap data for a show", hidden: true
      post ":date/recompute_gaps", requirements: DATE do
        enqueue_job("recompute_gaps", Admin::RecomputeGapsJob, show: admin_show)
      end

      desc "Unpack and transcode uploads into mp3 blobs for a bulk upsert", hidden: true
      params do
        requires :signed_ids, type: Array[String]
      end
      post ":date/bulk_audio_prepare", requirements: DATE do
        enqueue_job("bulk_audio_prepare", Admin::PrepareBulkAudioJob, show: admin_show, args: [ params[:signed_ids] ])
      end

      desc "Plan a bulk audio upsert against a show's tracks", hidden: true
      params do
        requires :signed_ids, type: Array[String]
      end
      post ":date/bulk_audio_match", requirements: DATE do
        show = admin_show
        blobs = params[:signed_ids].map { |id| find_signed_blob(id) }
        status 200
        BulkAudioMatcher.call(show:, blobs:)
      end

      desc "Apply a planned bulk audio upsert", hidden: true
      params do
        requires :assignments, type: Array do
          requires :signed_id, type: String
          requires :track_id, type: Integer
        end
      end
      post ":date/bulk_audio_apply", requirements: DATE do
        show = admin_show
        assignments = declared(params)[:assignments].map do |a|
          { "signed_id" => a[:signed_id], "track_id" => a[:track_id] }
        end
        validate_assignments!(show, assignments)
        enqueue_job("bulk_replace_audio", Admin::BulkReplaceAudioJob, show:, args: [ assignments ])
      end

      desc "Update show attributes", hidden: true
      params do
        optional :venue_id, type: Integer
        optional :tour_id, type: Integer
        optional :taper_notes, type: String
        optional :admin_notes, type: String
        optional :performance_gap_value, type: Integer
        optional :matches_pnet, type: Boolean
        optional :cover_art_prompt, type: String
        optional :cover_art_parent_show_id, type: Integer
      end
      patch ":date", requirements: DATE do
        show = admin_show
        show.update!(show_updates)
        editor_payload(show.reload)
      end

      desc "Reorder tracks", hidden: true
      params do
        requires :track_ids, type: Array[Integer]
        optional :sets, type: Hash, default: {}
      end
      put ":date/track_order", requirements: DATE do
        show = admin_show
        if params[:track_ids].sort != show.tracks.pluck(:id).sort
          error!({ message: "track_ids must include every track exactly once" }, 422)
        end
        sets = params[:sets].to_h { |id, set| [ id.to_i, set ] }
        unless sets.keys.all? { |id| params[:track_ids].include?(id) } &&
               sets.values.all? { |set| ApiV2::Admin::Tracks::VALID_SETS.include?(set) }
          error!({ message: "sets must map tracks of this show to valid sets" }, 422)
        end
        ActiveRecord::Base.transaction do
          sets.each { |id, set| show.tracks.find(id).update!(set:) }
          show.renumber_tracks!(params[:track_ids])
        end
        editor_payload(show.reload)
      end

      desc "Insert a track", hidden: true
      params do
        requires :position, type: Integer
        requires :title, type: String
        requires :set, type: String, values: ApiV2::Admin::Tracks::VALID_SETS
        requires :song_ids, type: Array[Integer]
        optional :signed_id, type: String
      end
      post ":date/tracks", requirements: DATE do
        show = admin_show
        songs = Song.where(id: params[:song_ids]).to_a
        error!({ message: "at least one song is required" }, 422) if songs.empty?
        track = nil
        ActiveRecord::Base.transaction do
          show.tracks.where(position: params[:position]..).order(position: :desc).each do |t|
            t.update!(position: t.position + 1)
          end
          track = show.tracks.create!(
            position: params[:position],
            title: params[:title],
            set: params[:set],
            audio_status: "missing",
            songs:
          )
        end
        payload = editor_payload(show.reload)
        if params[:signed_id].present?
          payload.merge!(enqueue_job("replace_audio", Admin::ReplaceAudioJob, show:, track:, args: [ params[:signed_id] ]))
        end
        status 201
        payload
      end

      desc "Delete a show", hidden: true
      delete ":date", requirements: DATE do
        show = admin_show
        if AdminJob.active.where(show:).exists?
          error!({ message: "A job is still running for this show; cancel it or wait for it to finish" }, 422)
        end
        show.destroy!
        status 204
        body false
      end
    end
  end

  helpers do
    def show_updates
      updates = declared(params, include_missing: false).except(:date).symbolize_keys
      updates[:venue] = lookup_or_nil(Venue, updates.delete(:venue_id)) if updates.key?(:venue_id)
      updates[:tour] = lookup_or_nil(Tour, updates.delete(:tour_id)) if updates.key?(:tour_id)
      updates
    end

    def lookup_or_nil(klass, id)
      id.nil? ? nil : klass.find(id)
    end

    def validate_assignments!(show, assignments)
      track_ids = assignments.map { |a| a["track_id"] }
      if track_ids.uniq.size != track_ids.size
        error!({ message: "Each track may appear only once" }, 422)
      end
      known = show.tracks.where(id: track_ids).pluck(:id)
      missing = track_ids - known
      return if missing.empty?
      error!({ message: "Tracks not on #{show.date}: #{missing.join(', ')}" }, 422)
    end
  end
end
