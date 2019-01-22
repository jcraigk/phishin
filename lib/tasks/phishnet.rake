# frozen_string_literal: true
namespace :phishnet do
  desc 'Sync jamcharts data'
  task jamcharts: :environment do
    puts 'Fetching Jamcharts data from Phish.net API...'
    JamchartsImporter.new(ENV['PNET_API_KEY']).call
  end

  task setlist_tags: :environment do
    relation = Show.unscoped.order(date: :asc)

    # rig_tag = Tag.find_by(name: 'Alternate Rig')
    # TrackTag.where(tag: rig_tag).destroy_all

    # guest_tag = Tag.find_by(name: 'Guest')
    # TrackTag.where(tag: guest_tag).destroy_all

    debut_tag = Tag.find_by(name: 'Debut')
    TrackTag.where(tag: debut_tag).destroy_all

    phish_debut_tag = Tag.find_by(name: 'Phish Debut')
    TrackTag.where(tag: phish_debut_tag).destroy_all

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

        tag = nil
        if text.downcase.include?('phish debut')
          tag = phish_debut_tag
        elsif text.downcase.include?('debut')
          tag = debut_tag
        end
        next unless tag

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
        next puts "Missing: #{date} #{title}" unless track

        TrackTag.create(track: track, tag: tag)
      end

      pbar.increment
    end

    pbar.finish
  end
end
