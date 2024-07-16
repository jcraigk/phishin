import $ from 'jquery'
import 'jquery-ui/ui/widgets/slider'
import 'jquery-ui/ui/widgets/tooltip'

import Util from './util.js'

class Player
  constructor: ->
    @Util             = new Util
    @app_name         = 'Phish.in'
    @active_track_id  = ''
    @active_show_id   = ''
    @scrubbing        = false
    @duration         = 0
    @playlist_mode    = false
    @audioContext     = new (window.AudioContext || window.webkitAudioContext)()
    @currentSource    = null
    @nextSource       = null
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

  playTrack: (track_id, time_marker=0) ->
    @active_track_id = track_id
    this._loadTrack()
    this._highlightActiveItem()

  _loadTrack: ->
    $.ajax
      url: "/track-info/#{@active_track_id}"
      success: (r) =>
        if r.success
          this._updateDisplay r
          this._updateMediaSession r
          @currentSource = null
          @nextSource = null
          this._loadAndPlayAudio r.mp3_url, r.next_mp3_url
          @active_show_id = r.show_id

  _loadAndPlayAudio: (url, next_url) =>
    fetch(url)
      .then (response) =>
        response.arrayBuffer()
      .then (data) =>
        @audioContext.decodeAudioData(data)
      .then (buffer) =>
        @currentSource = @audioContext.createBufferSource()
        @currentSource.buffer = buffer
        @currentSource.connect(@audioContext.destination)
        @currentSource.start()
        @currentSource.onended = => @._playNextBuffer()
        @._preloadNextTrack(next_url)
      .catch (error) =>
        console.error('Error loading or decoding audio:', error)


  _preloadNextTrack: (url) =>
    fetch(url)
      .then (response) ->
        response.arrayBuffer()
      .then (data) ->
        @audioContext.decodeAudioData(data)
      .then (buffer) =>
        @nextSource = @audioContext.createBufferSource()
        @nextSource.buffer = buffer
        @nextSource.connect(@audioContext.destination)
      .catch (error) ->
        console.error('Error preloading next track:', error)


  _playNextBuffer: ->
    if @nextSource
      @nextSource.start(0)
      @currentSource = @nextSource
      @nextSource = null
      this.nextTrack()

  nextTrack: ->
    return if @playlist_mode
    $.ajax
      url: "/next-track/#{@active_track_id}"
      success: (r) =>
        if r.success
          @active_track_id = r.track_id
          this._preloadNextTrack(r.next_mp3_url)
          this._highlightActiveItem()
        else
          @Util.feedback { alert: r.msg }

  _highlightActiveItem: ->
    if @active_track_id
      $show = $('.playable_show[data-id="'+@active_show_id+'"]')
      $track = $('.playable_track[data-id="'+@active_track_id+'"]')
      $('.playable_track').removeClass 'active_track'
      $track.addClass 'active_track'
      $show.addClass 'active_track'
      if $track.length > 0
        $el = $track.first()
      if $el
        $('html,body').animate {scrollTop: $el.offset().top - 300}, 500

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
          src: 'https://phish.in/static/logo-512.png',
          sizes: '512x512',
          type: 'image/png'
        }
      ]

  _updatePlayButton: ->
    if not @currentSource or @audioContext.state == 'suspended'
      @$playpause.removeClass 'playing'
    else
      @$playpause.addClass 'playing'
      @$playpause.removeClass 'pulse'

  togglePause: ->
    if @currentSource
      if @audioContext.state == 'running'
        @audioContext.suspend()
        navigator.mediaSession.playbackState = 'paused'
      else
        @audioContext.resume()
        navigator.mediaSession.playbackState = 'playing'
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
    if @currentSource?.buffer and @audioContext.currentTime > 3
      @currentSource.stop()
      @currentSource.start(0)
    else
      $.ajax
        url: "/previous-track/#{@active_track_id}"
        success: (r) =>
          if r.success
            this.playTrack r.track_id
          else
            @Util.feedback { alert: r.msg }

  stopAndUnload: ->
    if @currentSource
      @currentSource.stop()
    @active_track_id = ''
    this._updateDisplay
      title: '',
      duration: 0
    @$scrubber.slider 'value', 0
    @$scrubber.slider 'disable'
    this._updatePlayButton()
    @$time_remaining.html '0:00'
    @$time_elapsed.html '0:00'

export default Player
