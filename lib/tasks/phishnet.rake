namespace :phishnet do
  desc 'Populate known dates'
  task known_dates: :environment do
    puts 'Fetching known dates from Phish.net API...'
    url = "https://api.phish.net/v5/shows.json?apikey=#{ENV['PNET_API_KEY']}"
    JSON.parse(Typhoeus.get(url).body)['data'].each do |entry|
      next unless entry['artist_name'] == 'Phish' &&
                  entry['exclude_from_stats'] != '1'

      setlist_url = "https://api.phish.net/v5/setlists/showdate/#{entry['showdate']}.json?apikey=#{ENV['PNET_API_KEY']}"
      setlist_count = JSON.parse(Typhoeus.get(setlist_url).body)['data'].size
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

  desc 'Compare local setlists with Phish.net'
  task compare_setlists: :environment do
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

    shows = Show.published
                .where(incomplete: false)
                .where(matches_pnet: false)
                .order(date: :asc)
    pbar = ProgressBar.create \
      total: shows.count,
      format: '%a %B %c/%C %p%% %E'

    shows.each do |show|
      url = "https://api.phish.net/v5/setlists/showdate/#{show.date}.json?apikey=#{ENV['PNET_API_KEY']}"
      data = JSON.parse(Typhoeus.get(url).body)
      sa = data['data'].reject { |d| d['artist_name'] != 'Phish' }
                       .map { |d| [d['set'].upcase, d['song']] }
      sb = expand \
        show.tracks
            .where.not(title: %w[Banter Narration])
            .where.not(set: 'S')
            .order(:position)
            .map { |t| [t.set, t.title] }
      if sa == sb
        show.update(matches_pnet: true)
      else
        binding.irb
      end
      pbar.increment
    end

    pbar.finish
  end
end
