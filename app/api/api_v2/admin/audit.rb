# Read surfaces over the append-only TrackEdit log and over the tags an audio
# operation left behind.
#
# Both are reads. Resolving an orphan is an ordinary tag edit through
# PATCH /admin/track_tags/:id, which already writes timestamps and now also
# clears the flag, so nothing here mutates anything.
class ApiV2::Admin::Audit < ApiV2::Admin::Base
  helpers ApiV2::Helpers::AdminHelper

  before { authenticate_admin! }

  namespace :admin do
    resource :shows do
      # Scoped to the SHOW, not to a track, and this is load-bearing rather than
      # a convenience. A combine destroys a track and its foreign key nullifies,
      # so an edit whose subject is gone carries track_id nil and no per-track
      # query can ever reach it. show_id is what still finds it, so the history
      # is fetched per show and grouped here into one bucket per surviving track
      # plus one for the edits whose track no longer exists.
      desc "Audit history for every track on a show", hidden: true
      get ":date/history", requirements: { date: /\d{4}-\d{2}-\d{2}/ } do
        show = admin_show
        edits = show.track_edits.newest_first.includes(:user, :admin_job)
        { history: history_payload(show, edits) }
      end
    end

    resource :track_tags do
      desc "List every tag orphaned by an audio operation", hidden: true
      params do
        optional :limit, type: Integer, default: 100, values: 1..500
      end
      get :orphaned do
        track_tags =
          TrackTag.where.not(orphaned_at: nil)
                  .order(orphaned_at: :desc, id: :desc)
                  .limit(params[:limit])
                  .includes(:tag, track: :show)
        { orphans: track_tags.map { orphan_payload(it) } }
      end
    end
  end

  helpers do
    # One group per current track in position order, then a final group for the
    # edits whose track_id was nullified. The nullified group is omitted when it
    # is empty rather than rendered as an empty section, so a show that never
    # lost a track does not carry an explanation it does not need.
    def history_payload(show, edits)
      by_track = edits.group_by(&:track_id)
      groups = show.tracks.order(:position).map do |track|
        {
          track_id: track.id,
          position: track.position,
          title: track.title,
          duration: track.duration,
          edits: (by_track[track.id] || []).map { edit_payload(it) }
        }
      end
      orphaned = by_track[nil] || []
      return groups if orphaned.empty?

      groups + [ {
        track_id: nil,
        position: nil,
        title: nil,
        duration: nil,
        edits: orphaned.map { edit_payload(it) }
      } ]
    end

    # payload is handed through whole. The model deliberately does not validate
    # its shape, so an operation that recorded something this UI does not know
    # about is still delivered rather than filtered out on the way to the
    # browser.
    def edit_payload(edit)
      {
        id: edit.id,
        operation: edit.operation,
        created_at: edit.created_at,
        admin_job_id: edit.admin_job_id,
        user_email: edit.user&.email,
        payload: edit.payload
      }
    end

    # The original numbers ride along untouched. They are what the tag used to
    # point at, which is the only evidence an admin has when deciding where it
    # should point now, so they are never recomputed or presented as current.
    def orphan_payload(track_tag)
      track = track_tag.track
      {
        id: track_tag.id,
        tag_name: track_tag.tag.name,
        notes: track_tag.notes,
        starts_at_second: track_tag.starts_at_second,
        ends_at_second: track_tag.ends_at_second,
        orphaned_at: track_tag.orphaned_at,
        orphan_reason: track_tag.orphan_reason,
        track_id: track.id,
        track_title: track.title,
        track_position: track.position,
        track_duration: track.duration,
        show_id: track.show_id,
        show_date: track.show.date.to_s
      }
    end
  end
end
