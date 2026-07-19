class TrackTagDedupeService < ApplicationService
  def call
    removed = 0

    duplicate_groups.each do |group|
      ids = TrackTag.where(
        tag_id: group.tag_id,
        track_id: group.track_id,
        notes: group.notes,
        starts_at_second: group.starts_at_second,
        ends_at_second: group.ends_at_second,
        transcript: group.transcript
      ).order(:id).ids
      removed += TrackTag.where(id: ids.drop(1)).delete_all
    end

    puts "#{removed} duplicate track tags removed"
    removed
  end

  private

  def duplicate_groups
    TrackTag.select(:tag_id, :track_id, :notes, :starts_at_second, :ends_at_second, :transcript)
            .group(:tag_id, :track_id, :notes, :starts_at_second, :ends_at_second, :transcript)
            .having("count(*) > 1")
  end
end
