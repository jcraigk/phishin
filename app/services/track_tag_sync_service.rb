# frozen_string_literal: true
require 'csv'

class TrackTagSyncService
  attr_reader :tag, :data
  attr_reader :track, :created_ids, :updated_ids

  def initialize(tag_name, data)
    @data = data
    @tag = Tag.find_by!(name: tag_name)
  end

  def call
    @created_ids = []
    destroy_existing_track_tags
    sync_track_tags
    # create_csv_for_extra_track_tags
    puts "#{created_ids.size} tags synced"
  end

  private

  def destroy_existing_track_tags
    TrackTag.where(tag: tag).destroy_all
  end

  def sync_track_tags
    data.each do |row|
      @track = find_track_by_url(row['URL'])
      # existing = TrackTag.find_by(tag: tag, track: track)
      # existing ? update_track_tag(existing, row) : create_track_tag(row)
      create_track_tag(row)
    end
  end

  def create_track_tag(row)
    puts "Creating #{row['URL']}"
    @created_ids <<
      TrackTag.create(
        tag: tag,
        track: track,
        starts_at_second: seconds_or_nil(row['Starts At']),
        ends_at_second: seconds_or_nil(row['Ends At']),
        notes: row['Notes'],
        transcript: row['Transcript']
      ).id
  end

  def seconds_or_nil(str)
    return if str.nil? || str.empty?
    min, sec = str.split(':')
    min.to_i * 60 + sec.to_i
  end

  def find_track_by_url(url)
    Track.find_by(
      slug: track_slug(url),
      show: show_from_url(url)
    )
  end

  def show_from_url(url)
    Show.find_by(date: show_slug(url))
  end

  def path_segments(url)
    url.split('/')
  end

  def track_slug(url)
    path_segments(url).last
  end

  def show_slug(url)
    path_segments(url)[-2]
  end


  # def update_track_tag(track_tag, row)
  #   puts "Updating #{row['URL']}"
  #   track_tag.update(
  #     starts_at_second: seconds_or_nil(row['Starts At']),
  #     ends_at_second: seconds_or_nil(row['Ends At']),
  #     notes: row['Notes']
  #   )
  #   @updated_ids << track_tag.id
  # end

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
