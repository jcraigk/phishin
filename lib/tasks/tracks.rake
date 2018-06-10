# frozen_string_literal: true
namespace :tracks do
  desc 'Generate generic slugs on all tracks'
  task create_slugs: :environment do
    Track.find_each do |track|
      slug = track.generic_slug
      track.update_attributes(slug: slug)
      puts "#{track.id} :: #{track.title} :: #{track.slug}"
    end
  end

  desc 'Ensure tracks have unique slugs within each show'
  task uniquify_slugs: :environment do
    Show.order('date desc').each do |show|
      puts "Working: #{show.date}"
      tracks = show.tracks.order('position asc').all
      tracks.each do |track|
        dupes = []
        tracks.each do |track2|
          next unless track.id != track2.id && track.slug == track2.slug
          dupes << track2
        end
        next unless dupes.any?

        num = 2
        dupes.each do |dupe_track|
          new_slug = "#{dupe_track.slug}-#{num}"
          puts "converting #{dupe_track.slug} to #{new_slug}"
          dupe_track.slug = new_slug
          dupe_track.save!
          num += 1
        end
      end
    end
  end

  desc 'Check for the same file being used for second occurrence of song within a show'
  task find_dupe_filenames: :environment do
    show_list = []
    Show.find_each do |show|
      filenames = show.tracks.map(&:audio_file_file_name)
      dupe = filenames.find { |f| filenames.count(f) > 1 }
      show_list << "#{show.date} :: #{dupe}" if dupe
    end
    puts "#{show_list.size} shows found with dupes"
    puts show_list.join("\n")
  end

  desc 'Check for position gaps in each show, searching for missing tracks'
  task find_missing: :environment do
    # Track gaps
    show_list = []
    Show.order('date desc').each do |show|
      show.tracks.order('position').each_with_index do |track, i|
        if i + 1 != track.position
          show_list << show.date
          break
        end
      end
    end
    if show_list.count.positive?
      puts "#{show_list.count} shows contain track gaps: #{show_list.join(',')}"
    else
      puts 'No track gaps found'
    end
    # Shows with no tracks
    show_list = []
    Show.where(missing: false).order('date desc').each do |show|
      tracks = show.tracks.all
      show_list << show.date unless tracks.any?
    end
    if show_list.count.positive?
      puts "#{show_list.count} shows contain no tracks: #{show_list.join(',')}"
    else
      puts 'No trackless shows found'
    end
  end

  desc 'Tighten up track positions within each show'
  task tighten_positions: :environment do
    Show.order('date desc').each do |show|
      puts "Tightening: #{show.date}"
      show.tracks.order('position asc').each_with_index do |track, idx|
        track.update_attributes(position: idx + 1)
      end
    end
  end

  desc 'Apply proper labels to track with NULL set property'
  task label_null_sets: :environment do
    tracks = Track.where('set IS NULL').order(:position)
    unknown = 0
    set = ''
    tracks.each do |track|
      filename = track.audio_file_file_name
      set =
        if filename[0..3] == 'II-e'
          'E'
        elsif filename[0..6] == '(Check)'
          'S'
        elsif filename[0..2] == 'III'
          '3'
        elsif filename[0..1] == 'II'
          '2'
        elsif filename[0] == 'I'
          '1'
        else
          ''
        end
      if set != ''
        track.set = set
        track.save
      else
        unknown += 1
      end
      puts "#{track.id} :: #{track.show.date} #{track.title} :: #{set}"
    end
    puts "#{unknown} unknowns"
  end

  desc "Find tracks that don't have valid show associations"
  task find_dangling: :environment do
    track_list = []
    tracks = Track.all
    tracks.each do |track|
      track_list << track unless track.show
    end
    track_list.each do |track|
      puts "#{track.title} :: #{track.id}"
    end
  end

  desc "Set default ID3 tags on all Tracks' audio_files"
  task save_default_id3: :environment do
    tracks = Track.all
    tracks.each_with_index do |track, i|
      p "#{i + 1} of #{tracks.size} (#{track.title} - id #{track.id})"
      track.save_default_id3_tags
    end
  end

  desc 'Identify tracks that point to nonexistent shows'
  task find_orphans: :environment do
    show_ids = []
    Track.find_each do |t|
      next unless t.show.nil? && !show_ids.include?(t.show_id)
      show_ids << t.show_id
    end
    puts "Complete: #{show_ids.size} orphans found"
    puts show_ids
  end
end
