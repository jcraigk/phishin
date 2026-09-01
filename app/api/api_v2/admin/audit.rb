# Read surface over the tags an audio operation left behind.
#
# A read only. Resolving an orphan is an ordinary tag edit through
# PATCH /admin/track_tags/:id, which already writes timestamps and also
# clears the flag, so nothing here mutates anything.
class ApiV2::Admin::Audit < ApiV2::Admin::Base
  helpers ApiV2::Helpers::AdminHelper

  before { authenticate_admin! }

  namespace :admin do
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
