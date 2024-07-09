# frozen_string_literal: true
namespace :tracks do
  desc 'Fix bad slugs'
  task fix_slugs: :environment do
    rel = Track.where('slug SIMILAR TO ?', '\-\d').order(id: :desc)
    pbar = ProgressBar.create(
      total: rel.count,
      format: '%a %B %c/%C %p%% %E'
    )

    rel.each do |track|
      track.generate_slug(force: true)
      track.save!
      pbar.increment
    end

    pbar.finish
  end

  desc 'Generate waveform images from audio files'
  task generate_images: :environment do
    relation = Track.includes(:show).where(waveform_png_data: nil).order(id: :desc)
    pbar = ProgressBar.create(
      total: relation.count,
      format: '%a %B %c/%C %p%% %E'
    )

    relation.find_each do |track|
      track.generate_waveform_image
      puts "#{track.show.date} - #{track.title}"
      pbar.increment
    end

    pbar.finish
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
    Show.includes(:tracks)
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
    Show.includes(:tracks)
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
    Show.order(date: :desc).each do |show|
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

  desc 'Apply ID3 tags to entire MP3 library'
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
