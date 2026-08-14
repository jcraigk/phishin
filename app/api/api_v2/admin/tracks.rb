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

      desc "Merge a track into the previous track", hidden: true
      post ":id/combine_up" do
        track = Track.find(params[:id])
        show = track.show
        previous = show.tracks.find_by(position: track.position - 1)
        error!({ message: "No previous track to combine into" }, 422) if previous.nil?

        ActiveRecord::Base.transaction do
          previous.title = "#{previous.title} > #{track.title}"
          previous.generate_slug(force: true) unless show.published?
          previous.songs = (previous.songs + track.songs).uniq
          if !previous.mp3_audio.attached? && track.mp3_audio.attached?
            previous.mp3_audio.attach(track.mp3_audio.blob)
            previous.audio_status = "complete"
          end
          previous.save!
          track.destroy!
          renumber(show)
        end
        previous.process_mp3_audio if previous.mp3_audio.attached?

        # Grape defaults POST to 201; this modifies existing tracks rather than
        # creating a resource, so it reports 200.
        status 200
        editor_payload(show.reload)
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
