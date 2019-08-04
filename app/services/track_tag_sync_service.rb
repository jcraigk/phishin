# frozen_string_literal: true
require 'csv'

class TrackTagSyncService
  include ActionView::Helpers::SanitizeHelper
  include Syncable

  attr_reader :tag, :data
  attr_reader :track, :created_ids, :updated_ids, :dupes

  def initialize(tag_name, data)
    @data = data
    @tag = Tag.find_by!(name: tag_name)
    @dupes = []
    @created_ids = []
    @updated_ids = []
  end

  def call
    # destroy_existing_track_tags
    sync_track_tags
    # create_csv_for_extra_track_tags

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
      existing =
        if tag.name.in?(%w[Tease Signal])
          TrackTag.find_by(
            tag: tag,
            track: track,
            notes: row['Notes'],
            starts_at_second: seconds_or_nil(row['Starts At'])
          )
        else
          TrackTag.find_by(tag: tag, track: track)
        end
      existing ? update_track_tag(existing, row) : create_track_tag(row)
    end
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

  def update_track_tag(tt, row)
    print '-'
    tt.update(
      starts_at_second: seconds_or_nil(row['Starts At']),
      ends_at_second: seconds_or_nil(row['Ends At']),
      notes: sanitize_str(row['Notes']),
      transcript: sanitize_str(row['Transcript'])
    )
    @updated_ids << tt.id
  end

  # def csv_file
  #   "#{Rails.root}/tmp/tagit/#{tag.slug}_extras.csv"
  # end

  # def create_csv_for_extra_track_tags
  #   return puts 'No extra track tags found' unless extra_track_tags.any?
  #   CSV.open(csv_file, 'w') { |csv| csv_data(csv) }
  #   puts "#{csv_file} created with #{extra_track_tags.size} rows"
  # end

  # def csv_data(csv)
  #   extra_track_tags.each { |track_tag| csv << csv_row_for(track_tag) }
  # end

  # def csv_row_for(track_tag)
  #   [
  #     "#{APP_BASE_URL}/#{track_tag.track.show.date}/#{track_tag.track.slug}",
  #     DurationFormatter.new(track_tag.starts_at_second * 1000).call,
  #     DurationFormatter.new(track_tag.ends_at_second * 1000).call,
  #     track_tag.notes
  #   ]
  # end

  # def extra_track_tags
  #   @extra_track_tags ||= TrackTag.where(tag: tag).where.not(id: created_ids + updated_ids)
  # end
end
