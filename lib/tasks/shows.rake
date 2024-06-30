# frozen_string_literal: true
namespace :shows do
  desc 'Insert a track into a show at given position'
  task insert_track: :environment do
    opts = {
      date: ENV['DATE'],
      position: ENV['POSITION'],
      file: ENV['FILE'],
      title: ENV['TITLE'],
      song_id: ENV['SONG_ID'],
      set: ENV['SET'],
      is_sbd: ENV['SBD'].present?,
      slug: ENV['SLUG']
    }

    TrackInserter.new(opts).call
    puts 'Track inserted'
  end

  desc 'Import a show'
  task import: :environment do
    require "#{Rails.root}/app/services/show_importer"
    include ActionView::Helpers::TextHelper

    dates = Dir.entries(IMPORT_DIR).grep(/\d{4}\-\d{1,2}\-\d{1,2}\z/).sort
    next puts "❌ No shows found in #{IMPORT_DIR}" unless dates.any?

    puts "🔎 #{pluralize(dates.size, 'folder')} found"
    dates.each { |date| ShowImporter::Cli.new(date) }
  end

  desc 'Compare setlists with Phish.net'
  task match_pnet: :environment do
    # "A > B" => ["A", "B"]
    def expand(setlist)
      normalized = []
      setlist.each do |set, title|
        if title.include?(' > ')
          titles = title.split(' > ')
          titles.each { |t| normalized << [set, t] }
        else
          normalized << [set, title]
        end
      end
      normalized
    end

    shows = Show.published.where(incomplete: false).order(date: :asc)
    pbar = ProgressBar.create \
      total: shows.count,
      format: '%a %B %c/%C %p%% %E'

    shows.each do |show|
      url = "https://api.phish.net/v5/setlists/showdate/#{show.date}.json?apikey=#{ENV['PNET_API_KEY']}"
      sa = JSON.parse(Typhoeus.get(url).body)['data'].map { |d| [d['set'].upcase, d['song']] }
      sb = expand \
        show.tracks
            .where.not(title: 'Banter')
            .where(matches_pnet: false)
            .order(:position)
            .map { |t| [t.set, t.title] }
      if sa == sb
        show.update(matches_pnet: true)
      else

      end
      pbar.increment
    end

    pbar.finish
  end
end
