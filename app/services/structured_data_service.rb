class StructuredDataService < ApplicationService
  param :path

  CONTEXT = "https://schema.org".freeze

  PHISH = {
    "@type": "MusicGroup",
    name: "Phish",
    url: "https://phish.com",
    sameAs: [
      "https://phish.com",
      "https://en.wikipedia.org/wiki/Phish",
      "https://www.facebook.com/phish",
      "https://musicbrainz.org/artist/e01646f2-2a04-450d-8bf2-0d993082e058"
    ]
  }.freeze

  def call
    return home_graphs if path == "/"
    return show_graphs if date?
    return song_graphs if song?
    return venue_graphs if venue?
    return playlist_graphs if playlist?
    []
  end

  private

  def home_graphs
    [
      {
        "@context": CONTEXT,
        "@type": "WebSite",
        name: App.app_name,
        url: App.base_url,
        potentialAction: {
          "@type": "SearchAction",
          target: {
            "@type": "EntryPoint",
            urlTemplate: "#{App.base_url}/search?term={search_term_string}"
          },
          "query-input": "required name=search_term_string"
        }
      },
      { "@context": CONTEXT }.merge(PHISH)
    ]
  end

  def show_graphs
    show = Show.includes(:venue, :tracks).find_by(date:)
    return [] unless show

    track = slug ? show.tracks.find_by(slug:) : nil
    track ? [ music_recording(track, show) ] : [ music_event(show) ]
  end

  def music_event(show)
    {
      "@context": CONTEXT,
      "@type": "MusicEvent",
      name: "Phish at #{show.venue_name} on #{long_date(show.date)}",
      startDate: show.date.iso8601,
      eventStatus: "https://schema.org/EventScheduled",
      eventAttendanceMode: "https://schema.org/OfflineEventAttendanceMode",
      url: show.url,
      performer: PHISH,
      location: music_venue(show.venue, show.venue_name),
      image: show.album_cover_url
    }.compact
  end

  def music_recording(track, show)
    {
      "@context": CONTEXT,
      "@type": "MusicRecording",
      name: track.title,
      byArtist: PHISH,
      duration: iso8601_duration(track.duration),
      url: track.url,
      datePublished: show.date.iso8601,
      recordingOf: composition_ref(track)
    }.compact
  end

  def song_graphs
    return [] if slug.nil?
    song = Song.find_by(slug:)
    return [] unless song

    [ { "@context": CONTEXT }.merge(music_composition(song)) ]
  end

  def venue_graphs
    return [] if slug.nil?
    venue = Venue.find_by(slug:)
    place = venue && music_venue(venue, venue.name)
    return [] unless place

    [ { "@context": CONTEXT }.merge(place).merge(url: venue.url) ]
  end

  def playlist_graphs
    return [] if slug.nil?
    playlist = Playlist.includes(:tracks).find_by(slug:)
    return [] unless playlist

    [
      {
        "@context": CONTEXT,
        "@type": "MusicPlaylist",
        name: playlist.name,
        url: "#{App.base_url}/play/#{playlist.slug}",
        numTracks: playlist.tracks.size
      }
    ]
  end

  def music_venue(venue, name)
    return nil unless venue

    {
      "@type": "MusicVenue",
      name: name.presence || venue.name,
      address: {
        "@type": "PostalAddress",
        addressLocality: venue.city,
        addressRegion: venue.state,
        addressCountry: venue.country
      }.compact,
      geo: geo(venue)
    }.compact
  end

  def geo(venue)
    return nil unless venue.latitude && venue.longitude
    { "@type": "GeoCoordinates", latitude: venue.latitude, longitude: venue.longitude }
  end

  def music_composition(song)
    { "@type": "MusicComposition", name: song.title, composer: composer_for(song) }.compact
  end

  def composition_ref(track)
    song = track.songs.first
    return nil unless song
    music_composition(song)
  end

  def composer_for(song)
    if song.original
      PHISH
    elsif song.artist.present?
      { "@type": "MusicGroup", name: song.artist }
    end
  end

  def iso8601_duration(ms)
    return nil if ms.nil? || ms.zero?

    total = ms / 1000
    hours, rem = total.divmod(3600)
    minutes, seconds = rem.divmod(60)
    duration = "PT"
    duration += "#{hours}H" if hours.positive?
    duration += "#{minutes}M" if minutes.positive? || hours.positive?
    duration += "#{seconds}S"
    duration
  end

  def long_date(date)
    date.strftime("%B %-d, %Y")
  end

  def date?
    segments[0] =~ /^\d{4}-\d{2}-\d{2}$/
  end

  def date
    return nil unless date?
    @date ||= begin
      Date.parse(segments[0])
    rescue Date::Error
      nil
    end
  end

  def song?
    resource_type == "songs"
  end

  def venue?
    resource_type == "venues"
  end

  def playlist?
    resource_type == "play"
  end

  def segments
    @segments ||= path.split("/").reject(&:empty?)
  end

  def resource_type
    @resource_type ||= segments[0]
  end

  def slug
    @slug ||= segments[1]
  end
end
