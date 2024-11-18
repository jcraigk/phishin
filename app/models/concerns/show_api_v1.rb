module ShowApiV1
  extend ActiveSupport::Concern

  included do # rubocop:disable Metrics/BlockLength
    def as_json # rubocop:disable Metrics/MethodLength
      {
        id:,
        date: date.iso8601,
        duration:,
        incomplete:,
        sbd:,
        remastered:,
        tour_id:,
        venue_id:,
        likes_count:,
        taper_notes:,
        updated_at: updated_at.iso8601,
        venue_name:,
        location: venue&.location
      }
    end

    def as_json_api # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      {
        id:,
        date: date.iso8601,
        duration:,
        incomplete:,
        sbd:,
        remastered:,
        tags: show_tags_for_api,
        tour_id:,
        venue: venue.as_json,
        venue_name:,
        taper_notes:,
        likes_count:,
        tracks: tracks.sort_by(&:position).map(&:as_json_api),
        updated_at: updated_at.iso8601
      }
    end

    private

    def remastered
      tag_id = Tag.find_by(name: "Remastered")&.id
      tag_id ? ShowTag.exists?(show_id: id, tag_id:) : false
    end

    def sbd
      tag_id = Tag.find_by(name: "SBD")&.id
      tag_id ? ShowTag.exists?(show_id: id, tag_id:) : false
    end

    def show_tags_for_api
      show_tags.map { |show_tag| show_tag_json(show_tag) }.sort_by { |t| t[:priority] }
    end

    def show_tag_json(show_tag)
      {
        id: show_tag.tag.id,
        name: show_tag.tag.name,
        priority: show_tag.tag.priority,
        group: show_tag.tag.group,
        color: show_tag.tag.color,
        notes: show_tag.notes
      }
    end
  end
end
