# frozen_string_literal: true
require 'csv'

class TrackTagSyncService
  include ActionView::Helpers::SanitizeHelper
  include Syncable

  attr_reader :tag, :data, :track, :created_ids, :updated_ids, :dupes

  def initialize(tag_name, data)
    @data = data
    @tag = Tag.find_by!(name: tag_name)
    @dupes = []
    @created_ids = []
    @updated_ids = []
  end

  def call
    sync_track_tags

    if dupes.any?
      puts
      puts 'DUPES:'
      puts dupes
    end

    puts
    puts "#{created_ids.size} tags created"
    puts "#{updated_ids.size} tags updated"
  end

  private

  def destroy_existing_track_tags
    TrackTag.where(tag: tag).destroy_all
  end

  def sync_track_tags
    data.each do |row|
      @track = find_track_by_url(row['URL'])
      existing = existing_track_tag(row)
      existing ? update_track_tag(existing, row) : create_track_tag(row)
    end
  end

  def existing_track_tag(row)
    return TrackTag.find_by(tag: tag, track: track) unless tag.name.in?(%w[Tease Signal])
    TrackTag.find_by(
      tag: tag,
      track: track,
      notes: row['Notes'],
      starts_at_second: seconds_or_nil(row['Starts At'])
    )
  end

  def sanitize_str(str)
    return if str.nil?
    sanitize(str.gsub(/[”“]/, '"').gsub(/[‘’]/, "'"))
  end

  def create_track_tag(row)
    print '.'
    @created_ids <<
      TrackTag.create!(
        tag: tag,
        track: track,
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
