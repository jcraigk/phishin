# frozen_string_literal: true
namespace :phishnet do
  desc 'Populate known dates'
  task known_dates: :environment do
    puts 'Fetching known dates from Phish.net API...'
    url = "https://api.phish.net/v5/shows.json?apikey=#{ENV['PNET_API_KEY']}"
    JSON.parse(Typhoeus.get(url).body)['data'].each do |entry|
      next unless entry['artist_name'] == 'Phish' &&
                  entry['exclude_from_stats'] != '1'

      setlist_url = "https://api.phish.net/v5/setlists/showdate/#{entry['showdate']}.json?apikey=#{ENV['PNET_API_KEY']}"
      setlist_count = JSON.parse(Typhoeus.get(url).body)['data'].size
      next if setlist_count.zero?

      kdate = KnownDate.find_or_create_by(date: entry['showdate'])
      location = entry['city']
      location += ", #{entry['state']}" if entry['state'].present?
      location += ", #{entry['country']}" if entry['country'] != 'USA'
      kdate.update \
        phishnet_url: entry['permalink'],
        location:,
        venue: entry['venue']
      print '.'
    end
    puts 'done'
  end

  desc 'Sync jamcharts data'
  task jamcharts: :environment do
    puts 'Fetching Jamcharts data from Phish.net API...'
    JamchartsImporter.new(ENV['PNET_API_KEY']).call
  end

  desc 'Sync Unfinished tag from setlist notes'
  task unfinished: :environment do
    require 'ostruct'
    puts 'Fetching data from Phish.net API...'
    relation = Show.order(date: :desc)
    unfinished_tag = Tag.find_by(name: 'Unfinished')
    count = 0
    missing_tracks = []
    pbar = ProgressBar.create(total: relation.count, format: '%a %B %c/%C %p%% %E')
    relation.each do |show|
      url = "https://api.phish.net/v5/setlists/showdate/#{show.date}.json?apikey=#{ENV['PNET_API_KEY']}"
      data = JSON.parse(Typhoeus.get(url).body, object_class: OpenStruct).data
      next unless data.present?
      data.each do |song_data|
        next unless song_data.footnote.start_with?('Unfinished')
        show = Show.find_by(date: song_data.showdate)
        track = Track.find_by(show: show, title: song_data.song)
        next missing_tracks << "#{show.date} - #{song_data.song}" unless track
        next if track.tags.include?(unfinished_tag)
        track.tags << unfinished_tag
        count += 1
      end
      pbar.increment
    end
    puts "Added #{count} tags"
    puts "Missing tracks: #{missing_tracks.join(', ')}" if missing_tracks.any?
  end

  desc 'Syncs various tags and outputs CSVs for others'
  task setlist_tags: :environment do
    include ActionView::Helpers::SanitizeHelper

    relation = Show.order(date: :asc)

    debut_tag = Tag.find_by(name: 'Debut')
    signal_tag = Tag.find_by(name: 'Signal')
    acoustic_tag = Tag.find_by(name: 'Acoustic')

    csv_guest = []
    csv_alt_rig = []
    csv_signal = []

    pbar = ProgressBar.create(total: relation.count, format: '%a %B %c/%C %p%% %E')

    relation.each do |show|
      date = show.date
      # TODO: Use PNet API v5
      # resp =
      #   HTTParty.get(
      #     "https://api.phish.net/v3/setlists/get?apikey=#{ENV['PNET_API_KEY']}&showdate=#{date}"
      #   ).body
      data = JSON[resp].dig('response', 'data')&.first
      next unless data.present?

      notes = Nokogiri.HTML(data['setlistdata']).css('.setlist-song + sup')

      notes.each do |note|
        text = sanitize(note['title'].gsub(/[”“]/, '"').gsub(/[‘’]/, "'"))
        title = note.previous_sibling.content

        track =
          Track.where(show: show)
               .where(
                 'title = ? or title LIKE ? or title LIKE ? or title LIKE ? or title LIKE ?',
                 title,
                 "%> #{title}",
                 "#{title} >%",
                 "%> #{title} >%",
                 "#{title}, %"
               ).first
        # next puts "Missing: #{date} #{title}" unless track
        next unless track

        text.split(';').each do |txt|
          downtxt = txt.downcase

          tag = nil
          notes = nil
          if downtxt.include?('acoustic')
            tag = acoustic_tag
          elsif downtxt.include?('signal')
            if downtxt =~ /\A(.+), (.+) and (.+) signals/
              (1..3).each do |idx|
                csv_signal << [track.url, '', '', Regexp.last_match[idx].titleize.chomp('signal').strip.chomp(','), 'Imported from Phish.net setlist API']
              end
            elsif downtxt =~ /\A(.+) and (.+) signals/
              (1..2).each do |idx|
                csv_signal << [track.url, '', '', Regexp.last_match[idx].titleize.chomp('signal').strip.chomp(','), 'Imported from Phish.net setlist API']
              end
            elsif downtxt =~ /\A(.+) signal\z/
              csv_signal << [track.url, '', '', Regexp.last_match[1].titleize.chomp('signal').strip.chomp(','), 'Imported from Phish.net setlist API']
            else
              txt = txt.chomp('.').strip.chomp('signal').chomp('signal in intro').chomp(',')
              csv_signal << [track.url, '', '', txt, 'Imported from Phish.net setlist API']
            end

          elsif downtxt.include?('debut')
            tag = debut_tag
          elsif downtxt.include?('guest') || downtxt =~ /\son\s/
            if ['fish on', 'page on', 'trey on', 'mike on'].any? { |words| downtxt.include?(words) }
              csv_alt_rig << [track.url, '', '', txt.strip, 'Imported from Phish.net setlist API']
            elsif !downtxt.include?('based on')
              csv_guest << [track.url, '', '', txt.strip, 'Imported from Phish.net setlist API']
            end
          end
          next unless tag

          if (tt = TrackTag.find_by(track: track, tag: tag))
            tt.update(notes: notes)
          else
            TrackTag.create(track: track, tag: tag, notes: notes)
          end
        end
      end

      pbar.increment
    end

    CSV.open("#{Rails.root}/tmp/guest.csv", 'w') do |csv|
      csv_guest.each do |d|
        csv << d
      end
    end

    CSV.open("#{Rails.root}/tmp/alt_rig.csv", 'w') do |csv|
      csv_alt_rig.each do |d|
        csv << d
      end
    end

    CSV.open("#{Rails.root}/tmp/signal.csv", 'w') do |csv|
      csv_signal.each do |d|
        csv << d
      end
    end

    pbar.finish
  end
end
