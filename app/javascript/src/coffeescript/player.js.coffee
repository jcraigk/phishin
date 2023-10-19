import $ from 'jquery'
import 'jquery-ui/ui/widgets/slider'
import 'jquery-ui/ui/widgets/tooltip'

import Util from './util.js'

class Player
  constructor: ->
    @Util             = new Util
    @active_track_id  = ''
    @scrubbing        = false
    @duration         = 0
    @playlist_mode    = false
    @playlist         = []
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
    @app_name = $('body').data('app-name')
    @time_marker = @Util.timeToMS($('body').data('time-marker'))
    @$scrubber.slider()
    @$scrubber.slider('enable')
    this._updatePlaylistMode()
    this._highlightActiveTrack(true)

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

    # Play first track on the page if no audio playing, not a playlist page, and no track slug in URL
    unless @active_track_id or @playlist_mode or this._handleAutoPlayTrack()
      if track_id = $('.playable_track').first().data('id')
        path_segment = window.location.pathname.split('/')[1]
        this.setCurrentPlaylist track_id if path_segment isnt 'playlist' and path_segment isnt 'play'
        this.playTrack track_id

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
    txt = "You're entering Playlist Edit Mode. Any track you click will be added to the end of your active playlist. Are you sure you want to continue?"
    if @playlist_mode
      @playlist_mode = false
    else if confirm(txt)
      @playlist_mode = true
    this._updatePlaylistMode()

  _updatePlaylistMode: ->
    if @playlist_mode
      $('#playlist_mode_notice').show()
      $('#playlist_mode_label').html 'DONE EDITING'
    else
      $('#playlist_mode_notice').hide()
      $('#playlist_mode_label').html 'EDIT PLAYLIST'

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
        @audioElement.play()
        navigator.mediaSession.playbackState = 'playing'
      else
        @audioElement.pause()
        navigator.mediaSession.playbackState = 'paused'
      this._updatePlayButton()
    else
      this._playRandomShowOrPlaylist()

  previousTrack: ->
    if @audioElement.currentTime > 3
      @audioElement.currentTime = 0
    else
      $.ajax
        url: "/previous-track/#{@active_track_id}?playlist=#{@playlist}"
        success: (r) =>
          if r.success
            this.playTrack r.track_id
          else
            @Util.feedback { alert: r.msg }

  nextTrack: ->
    $.ajax
      url: "/next-track/#{@active_track_id}?playlist=#{@playlist}"
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
      title: @app_name,
      duration: 0
    @$scrubber.slider 'value', 0
    @$scrubber.slider 'disable'
    this._updatePlayButton
    @$time_remaining.html '0:00'
    @$time_elapsed.html '0:00'

  _highlightActiveTrack: (scroll_to_track=false)->
    if @active_track_id
      $track = $('.playable_track[data-id="'+@active_track_id+'"]')
      $playlist_track = $('#active_playlist>li[data-id="'+@active_track_id+'"]')
      $('.playable_track').removeClass 'active_track'
      $track.removeClass 'highlighted_track'
      $track.addClass 'active_track'
      $('#active_playlist>li').removeClass 'active_track'
      $playlist_track.addClass 'active_track'
      if scroll_to_track
        if $track.length > 0
          $el = $track.first()
        else if $playlist_track.length > 0
          $el = $playlist_track.first()
        if $el
          $('html,body').animate {scrollTop: $el.offset().top - 300}, 500

  setCurrentPlaylist: (track_id) ->
    $.ajax
      type: 'post'
      url: '/override-playlist'
      data: { 'track_id': track_id }
      success: (r) =>
        @playlist = r.playlist

  playRandomSongTrack: (song_id) ->
    $.ajax
      url: "/random-song-track/#{song_id}"
      success: (r) =>
        if r.success
          @Util.navigateTo r.url
          this.setCurrentPlaylist r.track_id
          this.playTrack r.track_id

  _handleAutoPlayTrack: ->
    if anchor_name = $('body').attr('data-anchor')
      $col = $('li[data-track-anchor='+anchor_name+']')
      $col = $('li[data-section-anchor='+anchor_name+']') if $col.length == 0
      if $col.length > 0
        $el = $col.first()
        $('html,body').animate {scrollTop: $el.offset().top - 300}, 500
        unless @active_track_id
          track_id = $el.data 'id'
          this.setCurrentPlaylist track_id
          this.playTrack track_id, @time_marker
        else
          $el.addClass 'highlighted_track'
        true
      else
        false
    else
      false

  _playRandomShowOrPlaylist: ->
    $.ajax
      url: "/next-track"
      success: (r) =>
        if r.success
          @Util.feedback { notice: 'Playing active playlist...'}
          this.playTrack r.track_id
        else
          $.ajax
            url: "/random-show"
            success: (r) =>
              if r.success
                @Util.feedback { notice: 'Playing random show...'}
                @Util.navigateTo r.url
                this.setCurrentPlaylist r.track_id
                this.playTrack r.track_id

  _loadTrack: ->
    $.ajax
      url: "/track-info/#{@active_track_id}",
      success: (r) =>
        if r.success
          this._updateDisplay r
          this._updateMediaSession r
          this._loadAndPlayAudio r.mp3_url
        else
          @Util.feedback { alert: "Error retrieving track info" }

  _updateDisplay: (r) ->
    @$scrubber_ctrl.css('opacity', 1)
    @$scrubber.css('background-color', 'transparent')
    @$scrubber.css('opacity', 0)
    @$waveform.css('background-image', "url(#{r.waveform_image_url})")
    # $('.ui-slider-range').css('mask-image', "url(#{r.waveform_image_url})") # TODO
    setTimeout( =>
      @$scrubber.animate({ opacity: 1 }, { duration: 1000 });
      @$scrubber.css('background-color', '#999999') # TODO
    , 500)
    @duration = Math.floor(r.duration / 1000)
    if r.title?.length > 26 then @$player_title.addClass 'long_title' else @$player_title.removeClass 'long_title'
    if r.title?.length > 50 then r.title = r.title.substring(0, 47) + '...'
    @$player_title.html r.title
    document.title = r.title + ' - ' + r.show + ' - ' + @app_name
    @$likes_count.html r.likes_count
    @$likes_link.data 'id', r.id
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
      @audioElement.addEventListener('canplay', => this._playAudio())
      @audioElement.addEventListener('ended', => this.nextTrack())
      @audioElement.addEventListener('timeupdate', => this._updateProgress())
    @audioContext = new AudioContext()
    @audioElement.src = url

  _playAudio: =>
    unless @audioElement.readyState >= 3
      @audioElement.addEventListener 'canplay', => this._playAudio()
    else
      if @audioContext.state == 'suspended'
        @$playpause.removeClass 'playing'
        @$playpause.addClass 'pulse'
        # alert('Press play button to listen')
      else
        @audioElement.play()
        navigator.mediaSession.playbackState = 'playing'
      this._updatePlayButton()

export default Player
