namespace :songs do
  desc "Import cover artists from Genius API"
  task import_artists: :environment do
    relation = Song.where(original: false, artist: nil).order(title: :asc)
    pbar = ProgressBar.create(
      total: relation.count,
      format: "%a %B %c/%C %p%% %E"
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

  def fetch_genius_data(path)
    JSON.parse(
      Typhoeus.get(
        "https://api.genius.com#{path}",
        headers: { "Authorization" => "Bearer #{ENV['GENIUS_API_TOKEN']}" }
      ).body,
      object_class: OpenStruct
    )
  end

  def search_for_song(song)
    artist = song.original? ? "phish" : song.artist&.downcase
    term = CGI.escape("#{song.title} #{artist}".squish)
    path = "/search?q=#{term}"
    data = fetch_genius_data(path)
  end
end
