class @Player

  constructor: ->
    @Util             = App.Util
    @sm               = soundManager
    @sm_sound         = {}
    @preload_time     = 5000
    @preload_started  = false
    @active_track     = ''
    @invoked          = false
    @muted            = false
    @scrubbing        = false
    @last_volume      = 100
    @duration         = 0
    @playlist_mode    = false
    @playlist         = []
    @app_name         = $('body').data 'app-name'
    @time_marker      = @Util.timeToMS $('body').data('time-marker')
    @$playlist_btn    = $ '#playlist_button'
    @$playpause       = $ '#control_playpause'
    @$scrubber        = $ '#scrubber'
    @$volume_slider   = $ '#volume_slider'
    @$volume_icon     = $ '#volume_icon'
    @$time_elapsed    = $ '#time_elapsed'
    @$time_remaining  = $ '#time_remaining'
    @$feedback        = $ '#player_feedback'
    @$player_title    = $ '#player_title'
    @$player_detail   = $ '#player_detail'
    @$likes_count     = $ '#player_likes_container > .likes_large > span'
    @$likes_link      = $ '#player_likes_container > .likes_large > a'
    @$feedback.hide()
    this._initStatsAPI()

  # Check for track anchor to scroll-to [and play]
  onReady: ->
    this._updatePlaylistMode()
    @$scrubber.slider 'enable'
    unless @playlist_mode or this._handleAutoPlayTrack()
      if track_id = $('.playable_track').first().data 'id'
        unless @invoked
          path_segment = window.location.pathname.split('/')[1]
          this.setCurrentPlaylist track_id if path_segment isnt 'playlist' and path_segment isnt 'play'
          this.playTrack track_id
          # iOS doesn't allow auto-play
          if /(iPhone|iPad|iPod)/g.test(navigator.userAgent)
            this.togglePause()
            alert 'Touch the Play button to begin playback. Your browser does not support auto-play.'

  currentPosition: ->
    @sm_sound.position

  togglePlaylistMode: ->
    if @playlist_mode
      @playlist_mode = false
    else if confirm 'You are about to enter Playlist Edit Mode.  In this mode, any track you click will be added to the end of your active playlist.  This playlist can then be saved and shared.  Are you sure you want to continue?'
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
    if @active_track
      @sm_sound.setPosition Math.round((@$scrubber.slider('value') / 100) * @duration)
    else
      @$scrubber.slider 'value', 0

  moveScrubber: ->
    if @scrubbing and @active_track
      scrubber_position = (@$scrubber.slider('value') / 100) * @duration
      @$time_elapsed.html @Util.readableDuration(scrubber_position)
      @$time_remaining.html "-#{@Util.readableDuration(@duration - scrubber_position)}"

  toggleMute: ->
    if @last_volume > 0
      if @muted
        @$volume_slider.slider 'value', @last_volume
        @$volume_icon.removeClass 'muted'
        @sm.setVolume @active_track, @last_volume if @active_track
        @muted = false
      else
        @last_volume = @$volume_slider.slider 'value'
        @$volume_slider.slider 'value', 0
        @$volume_icon.addClass 'muted'
        @sm.setVolume @active_track, 0 if @active_track
        @muted = true
    else
      @last_volume = @$volume_slider.slider 'value'

  updateVolumeSlider: (value) ->
    if @muted and value > 0
      @$volume_icon.removeClass 'muted'
      @muted = false
    else if !@muted and value is 0
      @$volume_icon.addClass 'muted'
      @muted = true
    @sm.setVolume @active_track, value

  playTrack: (track_id, time_marker=0) ->
    if track_id != @active_track
      @preload_started = false
      unless track_id and @sm_sound = @sm.getSoundById track_id
        this._hidePlayTooltip()
        @sm_sound = @sm.createSound
          id: track_id
          url: this._trackIDtoURL track_id
          whileloading: =>
            this._updateLoadingState track_id
          whileplaying: =>
            this._updatePlayerState()

      if @muted
        @sm.setVolume track_id, 0
      else
        @sm.setVolume track_id, @last_volume
      this._loadInfoAndPlay track_id, 0
      this._fastFadeout @active_track if @active_track
      @active_track = track_id
      @$feedback.hide()
      this._updateLoadingState track_id
      this._updatePlayButton()
      this.highlightActiveTrack()
    else
      # @Util.feedback { notice: 'That is already the current track' }

  togglePause: ->
    if @sm_sound.paused
      this._updatePlayButton()
      @sm_sound.togglePause()
    else
      if @active_track
        this._updatePlayButton false
        @sm_sound.togglePause()
      else
        this._playRandomShowOrPlaylist()

  previousTrack: ->
    if @sm_sound.position > 3000
      @sm_sound.setPosition 0
    else
      $.ajax
        url: "/previous-track/#{@active_track}?playlist=#{@playlist}"
        success: (r) =>
          if r.success
            this.playTrack r.track_id
          else
            @Util.feedback { alert: r.msg }

  nextTrack: ->
    $.ajax
      url: "/next-track/#{@active_track}?playlist=#{@playlist}"
      success: (r) =>
        if r.success
          this.playTrack r.track_id
        else
          @Util.feedback { alert: r.msg }

  stopAndUnload: ->
    this._fastFadeout @active_track
    @sm_sound.unload() if @sm_sound.loaded
    @active_track = ''
    this._updatePlayerDisplay
      title: @app_name,
      duration: 0
    @$scrubber.slider 'value', 0
    @$scrubber.slider 'disable'
    this._updatePlayButton false
    @$time_remaining.html '0:00'
    @$time_elapsed.html '0:00'
    @invoked = false

  highlightActiveTrack: (scroll_to_track=false)->
    if @active_track
      $track = $('.playable_track[data-id="'+@active_track+'"]')
      $playlist_track = $('#active_playlist>li[data-id="'+@active_track+'"]')
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
      url: '/reset-playlist'
      data: { 'track_id': track_id }
      success: (r) =>
        @playlist = r.playlist
    @$playlist_btn.addClass 'playlist_active'

  playRandomSongTrack: (song_id) ->
    $.ajax
      url: "/random-song-track/#{song_id}"
      success: (r) =>
        if r.success
          @Util.navigateTo r.url
          this.setCurrentPlaylist r.track_id
          this.playTrack r.track_id

  _loadInfoAndPlay: (track_id, time_marker) ->
    this._loadTrackInfo track_id
    @sm.setPosition track_id, time_marker
    @sm.play track_id, { onfinish: => this.nextTrack() }
    @invoked = true

  _handleAutoPlayTrack: ->
    if anchor_name = $('body').attr 'data-anchor'
      $col = $('li[data-track-anchor='+anchor_name+']')
      $col = $('li[data-section-anchor='+anchor_name+']') if $col.length == 0
      if $col.length > 0
        $el = $col.first()
        $('html,body').animate {scrollTop: $el.offset().top - 300}, 500
        if not @invoked
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
                # this.playTrack r.track_id

  _disengagePlayer: ->
    if @active_track
      @sm.setPosition @active_track, 0
      @sm_sound.play()
      @sm_sound.pause()
    @$scrubber.slider 'value', 0
    this._updatePlayButton false

  _preloadTrack: (track_id) ->
    unless track_id and @sm.getSoundById track_id
      this._hidePlayTooltip()
      @sm.createSound
        id: track_id
        url: this._trackIDtoURL track_id
        autoLoad: true
        whileloading: =>
          this._updateLoadingState track_id
        whileplaying: =>
          this._updatePlayerState()
      @sm.setVolume track_id, @last_volume

  _loadTrackInfo: (track_id) ->
    $.ajax
      url: "/track-info/#{track_id}",
      success: (r) =>
        if r.success
          this._updatePlayerDisplay r
          this._createStatsAPIEvent r
        else
          @Util.feedback { alert: "Error retrieving track info" }

  _updatePlayerDisplay: (r) ->
    @duration = r.duration
    if r.title.length > 26 then @$player_title.addClass 'long_title' else @$player_title.removeClass 'long_title'
    if r.title.length > 50 then r.title = r.title.substring(0, 47) + '...'
    @$player_title.html r.title
    @$likes_count.html r.likes_count
    @$likes_link.data 'id', r.id
    if r.liked
      @$likes_link.addClass 'liked'
    else
      @$likes_link.removeClass 'liked'
    if @duration is 0
      @$player_detail.html ''
      @$time_elapsed.html '0:00'
      @$time_remaining.html '0:00'
    else
      @$player_detail.html "<a class=\"show_date\" href=\"#{r.show_url}\">#{r.show}</a>&nbsp;&nbsp;&nbsp;<a href=\"#{r.venue_url}\">#{@Util.truncate(r.venue)}</a>&nbsp;&nbsp;&nbsp;<a href=\"#{r.city_url}\">#{r.city}</a>"

  _updatePlayButton: (playing=true) ->
    if playing
      @$playpause.addClass 'playing'
    else
      @$playpause.removeClass 'playing'

  _updatePlayerState: ->
    unless @scrubbing or @duration is 0
      unless isNaN @duration or isNaN @sm_sound.position
        # Preload next track if we're close to the end of this one
        if !@preload_started and @duration - @sm_sound.position <= @preload_time
          $.ajax
            url: "/next-track/#{@active_track}"
            success: (r) =>
              this._preloadTrack(r.track_id) if r.success
          @preload_started = true
        @$scrubber.slider 'value', (@sm_sound.position / @duration) * 100
        @$time_elapsed.html @Util.readableDuration(@sm_sound.position)
        remaining = @duration - @sm_sound.position
        if remaining > 0
          @$time_remaining.html "-#{@Util.readableDuration(remaining)}"
        else
          @$time_remaining.html '0:00'
      else
        @$time_elapsed.html '0:00'
        @$time_remaining.html '0:00'

  _updateLoadingState: (track_id) ->
    if @active_track is track_id
      percent_loaded = Math.floor (@sm_sound.bytesLoaded / @sm_sound.bytesTotal) * 100
      percent_loaded = 0 if isNaN(percent_loaded)
      if 0 < @time_marker < @sm_sound.duration
        @sm.setPosition track_id, @time_marker
        @time_marker = 0
      if percent_loaded is 100
        if @time_marker > 0
          @$player_title.addClass 'long_title'
          @$player_title.html 'Marker out of range...'
          @time_marker = 0

  _fastFadeout: (track_id) ->
    if track_id and sound = @sm.getSoundById track_id
      if @muted or sound.volume is 0
        sound.stop()
        @sm.setVolume track_id, @$volume_slider.slider('value')
      else
        if sound.volume < 10 then delta = 1 else delta = 3
        @sm.setVolume track_id, sound.volume - delta
        setTimeout( =>
          this._fastFadeout track_id
        , 10)

  _trackIDtoURL: (track_id) ->
    str = track_id.toString()
    str = '0' + str for i in [0..(8-str.length)] by 1
    "/audio/#{str[0..2]}/#{str[3..5]}/#{str[6..9]}/#{track_id}.mp3"

  _hidePlayTooltip: ->
    $('#playpause_tooltip').tooltip('destroy')

  ###########################################################################
  # PhishTrackStats
  ###########################################################################

  _initStatsAPI: ->
    PhishTracksStats.setup
      testMode: false
      auth: 'MDI5NDQ0NDQ1MzYxZjkxMzUzODliOGEwNGYyYjA3M2U6'

  _createStatsAPIEvent: (r) ->
    # Post 'listen' event to PhishTracksStats at 80% played
    pos = parseInt(r.duration * 0.8)
    @sm.clearOnPosition r.id, pos
    @sm_sound.onPosition pos, (eventPosition) =>
      PhishTracksStats.postPlay { streaming_site: 'phishin', event: 'listen', track_id: r.id }, (data) =>
        console.log "Listen event for Track ID #{r.id} posted to PhishTracksStats"
      , (data) ->
        console.error(data)
