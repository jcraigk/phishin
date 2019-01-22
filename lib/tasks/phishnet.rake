# frozen_string_literal: true
namespace :phishnet do
  desc 'Sync jamcharts data'
  task jamcharts: :environment do
    puts 'Fetching Jamcharts data from Phish.net API...'
    JamchartsImporter.new(ENV['PNET_API_KEY']).call
  end

  desc 'Syncs Debut/Phish Debut tags and outputs CSV for Guest/Alt Rig'
  task setlist_tags: :environment do
    relation = Show.unscoped.order(date: :asc)

    debut_tag = Tag.find_by(name: 'Debut')
    phish_debut_tag = Tag.find_by(name: 'Phish Debut')

    csv_guest = []
    csv_alt_rig = []

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
        text = note['title']
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
          if downtxt.include?('phish debut')
            tag = phish_debut_tag
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

          if ENV['CREATE_TAGS'] == 'true'
            if (tt = TrackTag.find_by(track: track, tag: tag))
              tt.update(notes: notes)
            else
              TrackTag.create(track: track, tag: tag, notes: notes)
            end
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

    pbar.finish
  end
end
