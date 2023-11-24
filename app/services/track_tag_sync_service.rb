require 'csv'

class TrackTagSyncService
  include ActionView::Helpers::SanitizeHelper
  include Syncable

  attr_reader :tag, :data, :track, :created_ids, :updated_ids, :dupes, :missing_tracks

  def initialize(tag_name, data)
    @data = data
    @tag = Tag.find_by!(name: tag_name)
    @missing_tracks = []
    @created_ids = []
    @updated_ids = []
  end

  def call
    sync_track_tags
    print_summary
  end

  private

  def print_errors
    return if missing_tracks.none?

    puts
    puts 'MISSING TRACKS:'
    puts missing_tracks
  end

  def print_summary
    print_errors

    puts
    puts "#{created_ids.size} tags created"
    puts "#{updated_ids.size} tags updated"
  end

  def sync_track_tags
    data.each do |row|
      @track = find_track_by_url(row['URL'])
      existing = existing_track_tag(row)
      existing ? update_track_tag(existing, row) : create_track_tag(row)
    end
  end

  def existing_track_tag(row)
    return TrackTag.find_by(tag:, track:) unless tag.name.in?(%w[Tease Signal])
    TrackTag.find_by(
      tag:,
      track:,
      notes: row['Notes'],
      starts_at_second: seconds_or_nil(row['Starts At'])
    )
  end

  def sanitize_str(str)
    return if str.nil?
    sanitize(str.gsub(/[”“]/, '"').gsub(/[‘’]/, "'"))
  end

  def create_track_tag(row)
    if track.blank?
      @missing_tracks << row['URL']
      print 'x'
    else
      print '.'
      @created_ids << new_track_tag_id(row)
    end
  end

  def new_track_tag_id(row)
    TrackTag.create!(
      tag:,
      track:,
      starts_at_second: seconds_or_nil(row['Starts At']),
      ends_at_second: seconds_or_nil(row['Ends At']),
      notes: sanitize_str(row['Notes']),
      transcript: sanitize_str(row['Transcript'])
    ).id
  end

  def update_track_tag(track_tag, row)
    print '-'
    track_tag.update(
      starts_at_second: seconds_or_nil(row['Starts At']),
      ends_at_second: seconds_or_nil(row['Ends At']),
      notes: sanitize_str(row['Notes']),
      transcript: sanitize_str(row['Transcript'])
    )
    @updated_ids << track_tag.id
  end
end
