# frozen_string_literal: true
namespace :phishnet do
  desc 'Populate known dates'
  task known_dates: :environment do
    puts 'Fetching known dates from Phish.net API...'

    bad_dates = ['2018-08-17', '2018-08-18', '2018-08-19']

    (1983..Time.current.year).each do |year|
      resp =
        HTTParty.post(
          'https://api.phish.net/v3/shows/query',
          body: {
            apikey: ENV['PNET_API_KEY'],
            year: year,
            order: 'ASC'
          }
        )
      data = JSON[resp.body]['response']['data']
      print "#{year}: "
      data.each do |entry|
        next unless entry['billed_as'] == 'Phish'
        next if bad_dates.include?(entry['showdate'])
        kdate = KnownDate.find_or_create_by(date: entry['showdate'])
        kdate.update(
          phishnet_url: entry['link'],
          location: entry['location']&.gsub(/ , /, ' '),
          venue: entry['venue']
        )
        print '.'
      end
      puts 'done'
    end
  end

  desc 'Sync jamcharts data'
  task jamcharts: :environment do
    puts 'Fetching Jamcharts data from Phish.net API...'
    JamchartsImporter.new(ENV['PNET_API_KEY']).call
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
      resp =
        HTTParty.get(
          "https://api.phish.net/v3/setlists/get?apikey=#{ENV['PNET_API_KEY']}&showdate=#{date}"
        ).body
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
