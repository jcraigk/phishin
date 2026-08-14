class ApiV2::Admin::Shows < ApiV2::Admin::Base
  helpers ApiV2::Helpers::AdminHelper

  before { authenticate_admin! }

  namespace :admin do
    resource :shows do
      desc "List shows for admin", hidden: true
      params do
        optional :published, type: Boolean, desc: "Filter by published state"
      end
      get do
        shows = Show.order(date: :desc)
        shows = shows.where(published: params[:published]) unless params[:published].nil?
        {
          shows: shows.limit(500).map { |show| show_summary(show) }
        }
      end

      desc "Create a draft show", hidden: true
      params do
        requires :date, type: String, regexp: /\A\d{4}-\d{2}-\d{2}\z/
      end
      post do
        if Show.exists?(date: params[:date])
          error!({ message: "Show already exists for #{params[:date]}" }, 409)
        end
        Show.create!(date: params[:date], published: false, audio_status: "missing")
        status 201
        { date: params[:date] }
      end

      desc "Fetch a show for editing", hidden: true
      get ":date", requirements: { date: /\d{4}-\d{2}-\d{2}/ } do
        editor_payload(admin_show)
      end

      desc "Attach staged audio files", hidden: true
      params do
        requires :signed_ids, type: Array[String]
      end
      post ":date/staged_audio", requirements: { date: /\d{4}-\d{2}-\d{2}/ } do
        show = admin_show
        show.staged_audio.attach(params[:signed_ids])
        status 201
        { staged_audio: staged_audio_payload(show.reload) }
      end

      desc "Run Phish.net matching against staged audio", hidden: true
      post ":date/import", requirements: { date: /\d{4}-\d{2}-\d{2}/ } do
        show = admin_show
        error!({ message: "Show is already published" }, 422) if show.published?
        error!({ message: "Show already has tracks" }, 422) if show.tracks.exists?
        job = AdminJob.create!(kind: "import", show:)
        Admin::ImportShowJob.perform_async(show.id, job.id)
        status 201
        { job_id: job.id }
      end

      # Splits do not recompute gaps: a show can take several splits, and running
      # per split would work from a half-changed set list. The editor offers this
      # once the splits are in; publishing a draft recomputes them anyway.
      desc "Recompute gap data for a show", hidden: true
      post ":date/recompute_gaps", requirements: { date: /\d{4}-\d{2}-\d{2}/ } do
        show = admin_show
        job = AdminJob.create!(kind: "recompute_gaps", show:)
        Admin::RecomputeGapsJob.perform_async(show.id, job.id)
        status 201
        { job_id: job.id }
      end

      desc "Update show attributes", hidden: true
      params do
        optional :venue_id, type: Integer
        optional :tour_id, type: Integer
        optional :taper_notes, type: String
        optional :admin_notes, type: String
        optional :performance_gap_value, type: Integer
        optional :matches_pnet, type: Boolean
      end
      patch ":date", requirements: { date: /\d{4}-\d{2}-\d{2}/ } do
        show = admin_show
        show.update!(show_updates)
        editor_payload(show.reload)
      end

      # Positions carry a uniqueness validation and a unique index scoped to the show,
      # so assigning final positions row by row would collide with a row that has not
      # moved yet. Every row is parked in the negative mirror of its target position
      # first (a range no real row occupies), then flipped positive.
      desc "Reorder tracks", hidden: true
      params do
        requires :track_ids, type: Array[Integer]
      end
      put ":date/track_order", requirements: { date: /\d{4}-\d{2}-\d{2}/ } do
        show = admin_show
        if params[:track_ids].sort != show.tracks.pluck(:id).sort
          error!({ message: "track_ids must include every track exactly once" }, 422)
        end
        ActiveRecord::Base.transaction do
          params[:track_ids].each_with_index do |id, index|
            Track.where(id:).update_all(position: -(index + 1))
          end
          show.tracks.where(position: ...0).each do |track|
            track.update_columns(position: -track.position)
          end
        end
        editor_payload(show.reload)
      end

      desc "Insert a track", hidden: true
      params do
        requires :position, type: Integer
        requires :title, type: String
        requires :set, type: String, values: ApiV2::Admin::Tracks::VALID_SETS
      end
      post ":date/tracks", requirements: { date: /\d{4}-\d{2}-\d{2}/ } do
        show = admin_show
        ActiveRecord::Base.transaction do
          # Descending order means each row moves into a slot the row above it has
          # already vacated, so no intermediate state duplicates a position.
          show.tracks.where(position: params[:position]..).order(position: :desc).each do |track|
            track.update!(position: track.position + 1)
          end
          show.tracks.create!(
            position: params[:position],
            title: params[:title],
            set: params[:set],
            audio_status: "missing"
          )
        end
        status 201
        editor_payload(show.reload)
      end

      # Destroy cascades to tracks, likes and show_tags, and enqueues an
      # ActiveStorage::PurgeJob per attachment. Purging a blob that a surviving
      # attachment still references is safe: the attachments foreign key makes the
      # blob's destroy raise InvalidForeignKey, which purge rescues, leaving the row
      # and the stored file intact. Never replace that with a bare blob delete.
      desc "Delete a show", hidden: true
      delete ":date", requirements: { date: /\d{4}-\d{2}-\d{2}/ } do
        admin_show.destroy!
        status 204
        body false
      end

      desc "Remove a staged audio file", hidden: true
      delete ":date/staged_audio/:attachment_id", requirements: { date: /\d{4}-\d{2}-\d{2}/ } do
        show = admin_show
        attachment = show.staged_audio_attachments.find(params[:attachment_id])
        blob_in_use = ActiveStorage::Attachment
                      .where(blob_id: attachment.blob_id)
                      .where.not(id: attachment.id)
                      .exists?
        blob_in_use ? attachment.destroy : attachment.purge
        { staged_audio: staged_audio_payload(show.reload) }
      end
    end
  end

  helpers do
    # Grape keeps explicitly supplied nils, so a nil venue_id or tour_id clears the
    # association rather than being ignored. Unknown ids raise RecordNotFound (404).
    def show_updates
      updates = declared(params, include_missing: false).except(:date).symbolize_keys
      updates[:venue] = lookup_or_nil(Venue, updates.delete(:venue_id)) if updates.key?(:venue_id)
      updates[:tour] = lookup_or_nil(Tour, updates.delete(:tour_id)) if updates.key?(:tour_id)
      updates
    end

    def lookup_or_nil(klass, id)
      id.nil? ? nil : klass.find(id)
    end
  end
end
