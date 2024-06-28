import $ from 'jquery'
import 'jquery-ui/ui/widgets/slider'
import 'jquery-ui/ui/widgets/tooltip'

import Util from './util.js'

class Player
  constructor: ->
    @Util             = new Util
    @app_name         = 'Phish.in'
    @active_track_id  = ''
    @scrubbing        = false
    @duration         = 0
    @playlist_mode    = false
    @$playpause       = $ '#control_playpause'
    @$scrubber        = $ '#scrubber'
    @$scrubber_ctrl   = $ '#scrubber_controls'
    @$waveform        = $ '#waveform'
    @$time_elapsed    = $ '#time_elapsed'
    @$time_remaining  = $ '#time_remaining'
    @$player_title    = $ '#player_title'
    @$player_detail   = $ '#player_detail'
    @$likes_count     = $ '#player_likes_container > .likes_large > span'
    @$likes_link      = $ '#player_likes_container > .likes_large > a'

  onReady: ->
    @time_marker = @Util.timeToMS($('body').data('time-marker'))
    @$scrubber.slider()
    @$scrubber.slider('enable')

    # Support next/prev buttons on mobile lock screens
    navigator.mediaSession.setActionHandler 'previoustrack', =>
      this.previousTrack()
    navigator.mediaSession.setActionHandler 'nexttrack', =>
      this.nextTrack()
    navigator.mediaSession.setActionHandler 'play', =>
      this.togglePause()
    navigator.mediaSession.setActionHandler 'pause', =>
      this.togglePause()
    navigator.mediaSession.setActionHandler 'stop', =>
      this.togglePause()

    # Autoplay if URL indicates show date (`1995-10-31`) or playlist (`/play/asdf`)
    path = window.location.pathname.split('/').filter(Boolean)
    if path.length > 0 && (/^\d{4}-\d{2}-\d{2}$/.test(path[0]) || path[0] == 'play')
      this.togglePause()

  currentPosition: ->
    if @active_track_id then @audioElement.currentTime else 0

  _updateProgress: ->
    unless @scrubbing or @duration == 0
      unless isNaN @duration
        @$scrubber.slider 'value', (@audioElement.currentTime / @duration) * 100
        @$time_elapsed.html @Util.readableDuration(@audioElement.currentTime)
        remaining = @duration - Math.floor(@audioElement.currentTime)
        if remaining > 0
          @$time_remaining.html "-#{@Util.readableDuration(remaining)}"
        else
          @$time_remaining.html '0:00'
      else
        @$time_elapsed.html '0:00'
        @$time_remaining.html '0:00'

  togglePlaylistMode: ->
    txt = "You're entering Playlist Edit Mode. Playback will be disabled. Any track you click will be added to the end of your active playlist. Are you sure you want to continue?"
    if @playlist_mode
      @playlist_mode = false
    else if confirm(txt)
      @playlist_mode = true
      this.togglePause()
    this._updatePlaylistMode()

  _updatePlaylistMode: ->
    if @playlist_mode
      $('#playlist_mode_notice').show()
      $('#save_playlist_btn').hide()
      $('#playlist_mode_label').html 'DONE EDITING'
    else
      $('#playlist_mode_notice').hide()
      $('#playlist_mode_label').html 'EDIT'

  startScrubbing: ->
    @scrubbing = true
    @$time_elapsed.addClass 'scrubbing'
    @$time_remaining.addClass 'scrubbing'
    this.moveScrubber()

  stopScrubbing: ->
    @scrubbing = false
    @$time_elapsed.removeClass 'scrubbing'
    @$time_remaining.removeClass 'scrubbing'
    if @active_track_id
      @audioElement.currentTime = Math.round((@$scrubber.slider('value') / 100) * @duration)
    else
      @$scrubber.slider 'value', 0

  moveScrubber: ->
    if @scrubbing and @active_track_id
      scrubber_position = (@$scrubber.slider('value') / 100) * @duration
      @$time_elapsed.html @Util.readableDuration(scrubber_position)
      @$time_remaining.html "-#{@Util.readableDuration(@duration - scrubber_position)}"

  playTrack: (track_id, time_marker=0) ->
    @active_track_id = track_id
    this._loadTrack()
    this._highlightActiveTrack()

  togglePause: ->
    if @active_track_id
      if @audioElement.paused
        unless @playlist_mode
          @audioElement.play()
          navigator.mediaSession.playbackState = 'playing'
      else
        @audioElement.pause()
        navigator.mediaSession.playbackState = 'paused'
      this._updatePlayButton()
    else if !@playlist_mode
      $.ajax
        type: 'POST'
        url: '/enqueue-tracks'
        data: { path: window.location.pathname }
        success: (r) =>
          if r.success
            @Util.navigateTo r.url if r.url?
            @Util.feedback { notice: r.msg } if r.msg?
            this.playTrack r.track_id

  previousTrack: ->
    return if @playlist_mode
    if @audioElement.currentTime > 3
      @audioElement.currentTime = 0
    else
      $.ajax
        url: "/previous-track/#{@active_track_id}"
        success: (r) =>
          if r.success
            this.playTrack r.track_id
          else
            @Util.feedback { alert: r.msg }

  nextTrack: ->
    return if @playlist_mode
    $.ajax
      url: "/next-track/#{@active_track_id}"
      success: (r) =>
        if r.success
          this.playTrack r.track_id
        else
          @Util.feedback { alert: r.msg }

  scrubBackward: ->
    @audioElement.currentTime = @audioElement.currentTime - 5

  scrubForward: ->
    @audioElement.currentTime = @audioElement.currentTime + 5

  stopAndUnload: ->
    if @active_track_id
      @audioElement.pause()
    @active_track_id = ''
    this._updateDisplay
      title: '',
      duration: 0
    @$scrubber.slider 'value', 0
    @$scrubber.slider 'disable'
    this._updatePlayButton
    @$time_remaining.html '0:00'
    @$time_elapsed.html '0:00'

  _highlightActiveTrack: ->
    if @active_track_id
      $track = $('.playable_track[data-id="'+@active_track_id+'"]')
      $playlist_track = $('#active_playlist>li[data-id="'+@active_track_id+'"]')
      $('.playable_track').removeClass 'active_track'
      $track.removeClass 'highlighted_track'
      $track.addClass 'active_track'
      $('#active_playlist>li').removeClass 'active_track'
      $playlist_track.addClass 'active_track'
      if $track.length > 0
        $el = $track.first()
      else if $playlist_track.length > 0
        $el = $playlist_track.first()
      if $el
        $('html,body').animate {scrollTop: $el.offset().top - 300}, 500

  setCurrentPlaylist: (track_id, time_marker=0) ->
    return if @playlist_mode
    $.ajax
      type: 'POST'
      url: '/enqueue-tracks'
      data: { track_id: track_id }
      success: (r) =>
        if r.success
          this.playTrack r.track_id, time_marker

  playRandomSongTrack: (song_id) ->
    $.ajax
      url: "/random-song-track/#{song_id}"
      success: (r) =>
        if r.success
          @Util.navigateTo r.url
          this.setCurrentPlaylist r.track_id

  _loadTrack: ->
    $.ajax
      url: "/track-info/#{@active_track_id}",
      success: (r) =>
        if r.success
          this._updateDisplay r
          this._updateMediaSession r
          this._loadAndPlayAudio r.mp3_url
        # else
        #   @Util.feedback { alert: "Error retrieving track info" }

  _updateDisplay: (r) ->
    @$scrubber_ctrl.css('opacity', 1)
    @$scrubber.css('background-color', 'transparent')
    @$scrubber.css('opacity', 0)
    @$waveform.css('background-image', "url(#{r.waveform_image_url})")
    $('.ui-slider-range').css('mask-image', "url(#{r.waveform_image_url})")
    setTimeout( =>
      @$scrubber.animate({ opacity: 1 }, { duration: 1000 });
    , 500)
    @duration = Math.floor(r.duration / 1000)
    if r.title?.length > 26 then @$player_title.addClass 'long_title' else @$player_title.removeClass 'long_title'
    if r.title?.length > 50 then r.title = r.title.substring(0, 47) + '...'
    @$player_title.html r.title
    long_title = "#{r.title} - #{r.show} - #{@app_name}"
    doctitle = if r.title and r.show then long_title else @app_name
    document.title = doctitle
    @$likes_count.html r.likes_count
    @$likes_link.data 'id', r.id
    if @time_marker > 0
      @$scrubber.slider 'value', ((@time_marker / 1000) / @duration) * 100
    if r.liked
      @$likes_link.addClass 'liked'
    else
      @$likes_link.removeClass 'liked'
    if @duration == 0
      @$player_detail.html ''
      @$time_elapsed.html '0:00'
      @$time_remaining.html '0:00'
    else
      @$player_detail.html "<a class=\"show_date\" href=\"#{r.show_url}\">#{r.show}</a>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#{r.venue_url}\">#{@Util.truncate(r.venue)}</a>"

  _updateMediaSession: (r) ->
    navigator.mediaSession.metadata = new MediaMetadata
      title: r.title,
      artist: "Phish - #{r.show}",
      album: "#{r.show} - #{r.venue}",
      artwork: [
        {
          src: 'https://phish.in/static/logo-96.png',
          sizes: '96x96',
          type: 'image/png'
        },
        {
          src: 'https://phish.in/static/logo-128.png',
          sizes: '128x128',
          type: 'image/png'
        },
        {
          src: 'https://phish.in/static/logo-192.png',
          sizes: '192x192',
          type: 'image/png'
        },
        {
          src: 'https://phish.in/static/logo-256.png',
          sizes: '256x256',
          type: 'image/png'
        },
        {
          src: 'https://phish.in/static/logo-384.png',
          sizes: '384x384',
          type: 'image/png'
        },
        {
          src: 'https://phish.in/static/logo-512.png',
          sizes: '512x512',
          type: 'image/png'
        }
      ]

  _updatePlayButton: ->
    if @audioElement.paused
      @$playpause.removeClass 'playing'
    else
      @$playpause.addClass 'playing'
      @$playpause.removeClass 'pulse'

  _loadAndPlayAudio: (url) ->
    unless @audioElement
      @audioElement = document.querySelector('audio')
      @audioElement.addEventListener('ended', => this.nextTrack())
      @audioElement.addEventListener('timeupdate', => this._updateProgress())
    @audioElement.src = url
    if @time_marker > 0
      @audioElement.currentTime = @time_marker / 1000
      @time_marker = 0 # Only first track should start at time marker
    this._playAudio()

  _playAudio: =>
    @audioElement.play().catch (error) ->
      # suppress errors and scroll to right if audio fails to play
      $('html, body').animate({ scrollLeft: $(document).width() }, 'smooth')
    navigator.mediaSession.playbackState = 'playing'
    this._updatePlayButton()

export default Player
