# frozen_string_literal: true
namespace :songs do
  desc 'Import song lyrics from Genius API'
  task import_lyrics: :environment do
    LYRICS_WORDS = 4_000 # If larger, don't import - it's junk

    relation =
      Song.where(
        original: true,
        instrumental: false,
        lyrics: nil
      ).order(title: :desc)
    pbar = ProgressBar.create(
      total: relation.count,
      format: '%a %B %c/%C %p%% %E'
    )

    missing_songs = []
    large_songs = []

    # Song.where(original: true).find_each do |song|
    relation.find_each do |song|

      # Search Genius for the song title
      data = search_for_song(song)
      song_path = data.response.hits.first&.result&.api_path
      next missing_songs << song.title if song_path.blank?

      # Fetch song data
      data = fetch_genius_data(song_path)
      lyrics_path = data.response.song.path
      next missing_songs << song.title if lyrics_path.blank?

      # Scrape lyrics from public path
      url = "https://genius.com#{lyrics_path}"
      html = HTTParty.get(url).body
      doc = Nokogiri::HTML(html)
      text = doc.css('.lyrics').first&.text&.strip

      next missing_songs << song.title if text.blank?
      next large_songs << "#{song.title}: #{url}" if text.size > LYRICS_WORDS

      puts ''
      puts '*************************'
      puts '*************************'

      if instrumental?(text)
        puts "Instrumental:: #{song.title}"
        song.update!(instrumental: true)
      else
        puts "Updating #{song.title}"
        puts text
        song.update!(lyrics: text)
      end

      pbar.increment
    end

    puts "Missing songs: #{missing_songs.sort}"
    puts "Large songs: #{large_songs.sort}"
    pbar.finish
  end

  desc 'Find bad lyrics by looking for long entries'
  task bad_lyrics: :environment do
    songs = Song.where.not(lyrics: nil).all
    data = songs.sort_by { |s| s.lyrics.size }
                .reverse
                .map { |s| [s.id, s.lyrics.size] }
    puts data.take(20)
  end

  desc 'Import cover artists from Genius API'
  task import_artists: :environment do
    relation = Song.where(original: false, artist: nil).order(title: :asc)
    pbar = ProgressBar.create(
      total: relation.count,
      format: '%a %B %c/%C %p%% %E'
    )

    missing_songs = []

    relation.find_each do |song|
      data = search_for_song(song)
      song_path = data.response.hits.first&.result&.api_path
      next missing_songs << song.title if song_path.blank?

      data = fetch_genius_data(song_path)
      artist = data.response.song&.primary_artist&.name

      next missing_songs << sont.title if artist.blank?

      puts "#{song.title} => #{artist}"
      song.update!(artist: artist)

      pbar.increment
    end

    pbar.finish
  end

  desc 'Export lyrics to textfile'
  task export_lyrics: :environment do
    File.open("#{Rails.root}/lyrics.txt", 'w') do |f|
      Song.where.not(lyrics: nil).find_each do |song|
        f.write("#{song.title}::::#{song.lyrics};;;;")
      end
    end
  end

  desc 'Import lyrics from textfile'
  task import_lyrics_text: :environment do
    File.open("#{Rails.root}/lyrics.txt").read.split(';;;;').each do |data|
      parts = data.split('::::')
      puts "Importing #{parts.first}"
      Song.find_by(title: parts.first).update(lyrics: parts.second)
    end
  end

  def fetch_genius_data(path)
    JSON.parse(
      HTTParty.get(
        "https://api.genius.com#{path}",
        headers: { 'Authorization' => "Bearer #{ENV['GENIUS_API_TOKEN']}" }
      ).body,
      object_class: OpenStruct
    )
  end

  def instrumental?(text)
    text.size < 200 && text.include?('Instrumental')
  end

  def search_for_song(song)
    artist = song.original? ? 'phish' : song.artist&.downcase
    term = CGI.escape("#{song.title} #{artist}".squish)
    path = "/search?q=#{term}"
    data = fetch_genius_data(path)
  end
end
