# frozen_string_literal: true
namespace :tracks do
  desc 'Generate missing slugs'
  task missing_slugs: :environment do
    Track.where('slug IS NULL OR slug = ?', '').find_each do |track|
      slug = track.generic_slug
      track.update_attributes(slug: slug)
      puts "#{track.id} :: #{track.title} :: #{track.slug}"
    end
  end

  desc 'Ensure tracks have unique slugs within each show'
  task uniquify_slugs: :environment do
    Show.unscoped.order(date: :desc).each do |show|
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
    Show.unscoped.find_each do |show|
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
    Show.unscoped
        .includes(:tracks)
        .order(date: :desc)
        .find_each do |show|
      show.tracks.sort_by(&:position).each_with_index do |track, i|
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
    Show.unscoped
        .includes(:tracks)
        .order(date: :desc)
        .find_each do |show|
      show_list << show.date unless show.tracks.any?
    end
    if show_list.count.positive?
      puts "#{show_list.count} shows contain no tracks: #{show_list.join(',')}"
    else
      puts 'No trackless shows found'
    end
  end

  desc 'Tighten up track positions within each show'
  task tighten_positions: :environment do
    Show.unscoped.order(date: :desc).each do |show|
      puts "Tightening: #{show.date}"
      show.tracks.order(position: :asc).each_with_index do |track, idx|
        track.update(position: idx + 1)
      end
    end
  end

  desc "Find tracks that don't have valid show associations"
  task find_dangling: :environment do
    track_list = []
    Track.unscoped.find_each do |track|
      track_list << track unless track.show.present?
    end
    track_list.each do |track|
      puts "#{track.title} :: #{track.id}"
    end
  end

  desc "Apply ID3 tags to entire MP3 library"
  task apply_id3: :environment do
    relation = Track.unscoped.order(id: :asc)
    pbar = ProgressBar.create(
      total: relation.size,
      format: '%a %B %c/%C %p%% %E'
    )

    relation.find_each do |track|
      track.apply_id3_tags
      pbar.increment
    end

    pbar.finish
  end
end
