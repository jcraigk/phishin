# frozen_string_literal: true
require 'open-uri'
require 'nokogiri'
require_relative '../pnet'

namespace :shows do
  desc 'Find mis-labeled sets on tracks'
  task sets: :environment do
    show_list = []
    Show.order('date desc').all.each do |show|
      set_list = show.tracks.order('position').all.map(&:set)
      set_list.map! do |set|
        case set
        when 'S' then 0
        when 'E' then 4
        when 'E2' then 5
        when 'E3' then 6
        else set.to_i
        end
      end
      next unless set_list.present?
      set_list.each_with_index do |set, idx|
        if set_list[idx + 1] && set > set_list[idx + 1]
          show_list << show
          break
        end
      end
    end
    show_list.each do |show|
      puts "Check: #{show.date}"
    end
  end

  desc 'Apply SBD tags to shows'
  task apply_sbd_tags: :environment do
    dates = %w(2014-06-24)
    dates.each do |date|
      show = Show.where(date: date).first
      next if show.nil?

      tag_names = show.tags.map(&:name)
      if tag_names.include?('sbd')
        puts "#{date}: Already has SBD tag"
      else
        ShowTag.create(show_id: show.id, tag_id: 1)
        puts "#{date}: Created SBD tag"
      end

      tracks = show.tracks
      next if tracks.nil?

      tracks.each do |track|
        tag_names = track.tags.map(&:name)
        if tag_names.include? 'SBD'
          puts "#{date} / #{track.title}: Already has SBD tag"
        else
          TrackTag.create(track_id: track.id, tag_id: 1)
          puts "#{date} / #{track.title}: Created SBD tag"
        end
      end
    end
  end

  desc 'Set shows.duration based on sum of all tracks'
  task calc_duration: :environment do
    Show.order('date desc').all.each do |show|
      next unless show.tracks.any?

      duration = show.tracks.map(&:duration).inject(0, &:+)
      show.duration = duration
      show.save
      puts "#{show.date}: #{duration}"
    end
  end

  desc 'Get songs from pnet api'
  task get_songs: :environment do
    require 'pnet'
    API_KEY = '448345A7B7688DDE43D0'.freeze
    pnet = PNet.new(API_KEY)

    setlist = pnet.shows_setlists_get('showdate' => ENV['date'])[0]
    songs = Nokogiri::HTML(setlist['setlistdata']).css('p.pnetset > a').map(&:content)

    songs.each_with_index do |song, i|
      p "#{i + 1}. #{song}"
    end
  end

  desc "Using phish.net, get list of shows we don't currently have audio for"
  task missing_report: :environment do
    API_KEY = '448345A7B7688DDE43D0'.freeze
    pnet = PNet.new(API_KEY)

    total_shows = {}
    missing_list = {}
    (1983..Time.now.year).each do |year|
      total_shows[year] = 0
      missing_list[year] = []
      data = pnet.shows_query('year' => year)
      data.each do |show_data|
        next if show_data[1].zero? || show_data[1] == 'No Shows Found'
        total_shows[year] += 1
        date = show_data['showdate']
        unless Show.find_by_date(date)
          missing_list[year] << date
          # Show.create(date: date)
        end
      end
      num_missing = missing_list[year].size
      percent = (total_shows[year] > 0 ? (num_missing.to_f / total_shows[year].to_f) * 100.0 : 0)
      puts "#{year}: missing #{num_missing} of #{total_shows[year]} (#{percent.round}%)"
    end
    total_missing = 0
    missing_list.each { |_, a| total_missing += a.size }
    overall_total_shows = 0
    total_shows.each { |_, num| overall_total_shows += num }
    percent = (overall_total_shows > 0 ? (total_missing.to_f / overall_total_shows.to_f) * 100.0 : 0)
    puts "TOTAL: missing #{total_missing} of #{overall_total_shows} (#{percent.round}%)"
  end

  desc 'Eliminate blank lines in taper notes content'
  task fix_taper_notes: :environment do
    Show.all.each do |show|
      next unless show.taper_notes
      fixed_str = show.taper_notes.gsub(/\n\n/, "\n")
      if show.taper_notes != fixed_str
        show.taper_notes = fixed_str
        show.save
      end
    end
  end
end
