# An append-only record of one audio-affecting operation on a track.
#
# This is a LOG, not state. Nothing in the app updates or destroys one: the
# whole value of the record is that it still says what happened after the audio
# it describes is gone. Both writes raise, so a stray `dependent: :destroy` or a
# well-meaning cleanup fails loudly rather than quietly erasing history.
#
# track_id is nullable and its foreign key nullifies rather than cascades,
# because a combine destroys a track row. The record of that combine has to
# survive its own subject; show_id is what still finds it afterwards.
#
# payload is jsonb, shaped by the caller. The expected keys, all optional
# except where an operation genuinely produced the value:
#
#   {
#     "duration_before_s" => 612.4,   # track duration before the edit
#     "duration_after_s"  => 609.4,   # track duration after it
#     "delta_s"           => -3.0,    # shift applied to every timestamp on the track
#     "shifted"           => [        # children whose windows moved with the audio
#       { "type" => "TrackTag", "id" => 42, "from" => 66.0, "to" => 63.0 }
#     ],
#     "orphaned"          => [        # children left outside the new audio, never deleted
#       { "type" => "TrackTag", "id" => 43, "at" => 700.0, "reason" => "past_new_end" }
#     ],
#     "backup_path"       => "/path/to/original.mp3", # where the pre-edit audio went
#     "notes"             => [ "tag 'Tease' spanned the cut and was split in two" ]
#   }
#
# TimestampShifter returns the shifted/orphaned shape; this model does not
# compute it and does not validate it, so an operation can record something the
# schema never anticipated rather than losing it.
class TrackEdit < ApplicationRecord
  # Every audio-affecting path in app/jobs/admin/. Enumerated from the jobs
  # themselves, not guessed. Anything that changes what a track's audio sounds
  # like, or how long it is, belongs here.
  #
  # "split" and "combine" are RETIRED: the admin UI moves an existing boundary
  # but never creates or removes one, so both were taken out of the browser and
  # live on only in lib/tasks/split_scan.rake. They stay in this list because a
  # record written before that change still carries them and this validates on
  # inclusion - removing them would make history invalid. Nothing writes them
  # now. spec/models/track_edit_spec.rb pins both halves of that.
  OPERATIONS = %w[
    trim
    split
    combine
    shift_boundary
    replace_audio
    bulk_replace_audio
  ].freeze

  class ImmutableError < StandardError; end

  belongs_to :track, optional: true
  belongs_to :show
  belongs_to :user, optional: true
  belongs_to :admin_job, optional: true

  validates :operation, inclusion: { in: OPERATIONS }

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  # The one way an operation writes its record. Compacts the payload so a key an
  # operation had no value for is absent rather than present-and-null, and folds
  # the shifter's three buckets in under their own names. shifted/clamped/orphaned
  # are always written, even when empty: "this operation moved nothing" and "this
  # operation was never asked" have to read differently in the history panel.
  def self.record!(track:, operation:, show: nil, admin_job: nil, user: nil,
                   shift: nil, **payload)
    payload = payload.compact.transform_keys(&:to_s)
    if shift
      payload["shifted"] = entries(shift[:shifted])
      payload["clamped"] = entries(shift[:clamped])
      payload["orphaned"] = entries(shift[:orphaned])
    end
    create!(
      track:, show: show || track&.show, admin_job:, user:,
      operation: operation.to_s, payload:
    )
  end

  # jsonb round-trips string keys, so the entries are normalized on the way in
  # and a spec reading them back sees what the history panel will.
  def self.entries(list)
    Array(list).map { it.transform_keys(&:to_s) }
  end
  private_class_method :entries

  def readonly? = persisted?

  def destroy
    raise ImmutableError, "TrackEdit is an append-only log and cannot be destroyed"
  end

  def destroy! = destroy

  def delete
    raise ImmutableError, "TrackEdit is an append-only log and cannot be deleted"
  end
end
