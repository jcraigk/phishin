class @Player
  
  constructor: ->
    @Util             = App.Util
    @sm               = soundManager
    @sm_sound         = {}
    @preload_time     = 40000
    @preload_started  = false
    @active_track     = ''
    @invoked          = false
    @muted            = false
    @scrubbing        = false
    @last_volume      = 100
    @duration         = 0
    @app_name         = $('body').data 'app-name'
    @time_marker      = @Util.timeToMS $('body').data('time-marker')
    @$playlist_btn    = $ '#playlist_button .btn'
    @$playpause       = $ '#playpause'
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
  
  # Check for track anchor to scroll-to [and play]
  onReady: ->
    unless this._handleAutoPlayTrack()
      if track_id = $('.playable_track').first().data 'id'
        if not @invoked
          this.setCurrentPlaylist track_id
          this.playTrack track_id if track_id

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
      @sm.setPosition @active_track, (@$scrubber.slider('value') / 100) * @duration
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
      unless @sm_sound = @sm.getSoundById track_id
        @sm_sound = @sm.createSound({
          id: track_id,
          url: "/play-track/#{track_id}",
          autoLoad: true if time_marker > 0,
          whileloading: =>
            this._updateLoadingState track_id
          whileplaying: =>
            this._updatePlayerState()
        })
      if @muted
        @sm.setVolume track_id, 0
      else
        @sm.setVolume track_id, @last_volume
      if time_marker > 0
        @$player_title.html 'Loading...'
        @$player_detail.html ''
      else
        this._loadInfoAndPlay track_id, 0
      this._fastFadeout @active_track if @active_track
      @active_track = track_id
      @$feedback.hide()
      this._updateLoadingState track_id
      this._updatePauseState()
      this.highlightActiveTrack()
    else
      # @Util.feedback { notice: 'That is already the current track' }
  
  togglePause: ->
    if @sm_sound.paused
      @sm_sound.resume()
      this._updatePauseState()
    else
      if @active_track
        this._fastFadeout @active_track, true
        this._updatePauseState false
      else
        this._playRandomShowOrPlaylist() unless this._handleAutoPlayTrack()
  
  previousTrack: ->
    if @active_track
      if @sm_sound.position > 3000
        @sm_sound.setPosition 0
      else
        $.ajax({
          url: "/previous-track/#{@active_track}",
          success: (r) =>
            this.playTrack r.track_id if r.success
        })
    else
      @Util.feedback { alert: 'You need to make a playlist to use that button' }
  
  nextTrack: ->
    if @active_track
      $.ajax({
        url: "/next-track/#{@active_track}",
        success: (r) =>
          if r.success
            this.playTrack r.track_id
          else
            @Util.feedback { notice: 'End of playlist reached'}
            this.stopAndUnload()
      })
    else
      @Util.feedback { alert: 'You need to make a playlist to use that button' }
  
  stopAndUnload: ->
    this._fastFadeout @active_track
    @sm_sound.unload()
    @active_track = ''
    this._updatePlayerDisplay({
      title: @app_name,
      duration: 0
    })
    @$scrubber.slider 'value', 0
    @$scrubber.slider 'disable'
    this._updatePauseState false
    @$time_remaining.html ''
    @$time_elapsed.html ''
    @invoked = false
  
  highlightActiveTrack: ->
    if @active_track
      $('.playable_track').removeClass 'active_track'
      $('.playable_track[data-id="'+@active_track+'"]').removeClass 'highlighted_track'
      $('.playable_track[data-id="'+@active_track+'"]').addClass 'active_track'
      $('#current_playlist>li').removeClass 'active_track'
      $('#current_playlist>li[data-id="'+@active_track+'"]').addClass 'active_track'

  setCurrentPlaylist: (track_id) ->
    $.ajax({
      type: 'post'
      url: '/reset-playlist',
      data: { 'track_id': track_id }
    })
    @$playlist_btn.addClass 'playing'

  _loadInfoAndPlay: (track_id, time_marker) ->
    this._loadTrackInfo track_id
    @sm.setPosition track_id, time_marker
    @sm.play track_id, { onfinish: => this.nextTrack() }
    @invoked = true

  _handleAutoPlayTrack: ->
    if anchor_name = $('body').attr 'data-anchor'
      $col = $ 'li[data-anchor='+anchor_name+']'
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
    $.ajax({
      url: "/next-track",
      success: (r) =>
        if r.success
          @Util.feedback { notice: 'Playing current playlist...'}
          this.playTrack r.track_id
        else
          $.ajax({
            url: "/random-show",
            success: (r) =>
              if r.success
                @Util.feedback { notice: 'Playing random show...'}
                @Util.navigateTo r.url
                this.setCurrentPlaylist r.track_id
                this.playTrack r.track_id
          })
    })

  _disengagePlayer: ->
    if @active_track
      @sm.setPosition @active_track, 0
      @sm_sound.play()
      @sm_sound.pause()
    @$scrubber.slider 'value', 0
    this._updatePauseState false

  _preloadTrack: (track_id) ->
    unless @sm.getSoundById track_id
      @sm.createSound({
        id: track_id,
        url: "/play-track/#{track_id}",
        autoLoad: true,
        whileloading: =>
          this._updateLoadingState track_id
        whileplaying: =>
          this._updatePlayerState()
      })
      @sm.setVolume track_id, @last_volume
  
  _loadTrackInfo: (track_id) ->
    $.ajax({
      url: "/track-info/#{track_id}",
      success: (r) =>
        if r.success
          this._updatePlayerDisplay r
        else
          @Util.feedback { alert: "Error retrieving track info (#{track_id})" }
    })
  
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
      @$time_elapsed.html ''
      @$time_remaining.html ''
    else
      @$player_detail.html "<a href=\"#{r.show_url}\">#{r.show}</a>&nbsp;&nbsp;&nbsp;<a href=\"#{r.venue_url}\">#{r.venue}</a>&nbsp;&nbsp;&nbsp;<a href=\"#{r.city_url}\">#{r.city}</a>"
  
  _updatePauseState: (playing=true) ->
    if playing
      @$playpause.addClass 'playing'
    else
      @$playpause.removeClass 'playing'
  
  _updatePlayerState: ->
    unless @scrubbing or @duration is 0
      unless isNaN @duration or isNaN @sm_sound.position
        # Preload next track if we're close to the end of this one
        if !@preload_started and @duration - @sm_sound.position <= @preload_time
          $.ajax({
            url: "/next-track/#{@active_track}",
            success: (r) =>
              this._preloadTrack(r.track_id) if r.success
          })
          @preload_started = true
        @$scrubber.slider 'value', (@sm_sound.position / @duration) * 100
        @$time_elapsed.html @Util.readableDuration(@sm_sound.position)
        remaining = @duration - @sm_sound.position
        if remaining > 0
          @$time_remaining.html "-#{@Util.readableDuration(remaining)}"
        else
          @$time_remaining.html ''
      else
        @$time_elapsed.html ''
        @$time_remaining.html ''
  
  _updateLoadingState: (track_id) ->
    if @active_track is track_id
      percent_loaded = Math.floor (@sm_sound.bytesLoaded / @sm_sound.bytesTotal) * 100
      percent_loaded = 0 if isNaN(percent_loaded)
      @$feedback.html "<i class=\"icon-download\"></i> #{percent_loaded}%"
      if 0 < @time_marker < @sm_sound.duration
        this._loadInfoAndPlay track_id, @time_marker
        @time_marker = 0
      if percent_loaded is 100
        if @time_marker > 0
          @$player_title.addClass 'long_title'
          @$player_title.html 'Time marker out of range...'
          @time_marker = 0
        @$scrubber.slider 'enable'
        @$feedback.addClass 'done'
        setTimeout( =>
          @$feedback.hide 'fade'
        , 2000)
      else
        @$feedback.show()
        @$scrubber.slider 'disable'
        @$feedback.removeClass 'done'
  
  _fastFadeout: (track_id, is_pause=false) ->
    sound = @sm.getSoundById track_id
    if @muted or sound.volume is 0
      if is_pause
        sound.pause()
      else
        sound.stop()
      @sm.setVolume track_id, @$volume_slider.slider('value')
    else
      if sound.volume < 10 then delta = 1 else delta = 3
      @sm.setVolume track_id, sound.volume - delta
      setTimeout( =>
        this._fastFadeout track_id, is_pause
      , 10)