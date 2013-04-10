class @Player
  
  constructor: ->
    @util             = App.Util
    @sm               = soundManager
    @sm_sound         = {}
    @preload_time     = 40000
    @preload_started  = false
    @active_track     = ''
    @muted            = false
    @scrubbing        = false
    @last_volume      = 100
    @duration         = 0
    @app_name         = $('body').data('app-name')
    @time_marker      = @util.timeToMS $('body').data('time-marker')
    @$playpause       = $ '#playpause'
    @$scrubber        = $ '#scrubber'
    @$volume_slider   = $ '#volume_slider'
    @$volume_icon     = $ '#volume_icon'
    @$time_elapsed    = $ '#time_elapsed'
    @$time_remaining  = $ '#time_remaining'
    @$feedback        = $ '#player_feedback'
    @$player_title    = $ '#player_title'
    @$player_detail   = $ '#player_detail'
    @$playlist_button = $ '#playlist_button .btn'
    @$likes_count     = $ '#player_likes_container > .likes_large > span'
    @$likes_link      = $ '#player_likes_container > .likes_large > a'
    @$feedback.hide()
  
  # Check for track anchor to scroll-to [and play]
  onReady: ->
    if anchor_name = $('body').data 'anchor'
      $el = $('li[data-anchor='+anchor_name+']')
      if $el.get 0
        $('html,body').animate({scrollTop: $el.offset().top - 300}, 500)
        if $('body').data('autoplay') == true
          this.playTrack($el.data('id'), @time_marker)
        else
          $el.addClass 'highlighted_track'
    else if $('body').data('autoplay') == true
      this.playTrack(track_id, @time_marker) if track_id = $('.playable_track').first().data('id')

  startScrubbing: ->
    @scrubbing = true
    @$time_elapsed.addClass('scrubbing')
    @$time_remaining.addClass('scrubbing')
    this.moveScrubber()
  
  stopScrubbing: ->
    @scrubbing = false
    @$time_elapsed.removeClass('scrubbing')
    @$time_remaining.removeClass('scrubbing')
    if @active_track
      @sm.setPosition(@active_track, (@$scrubber.slider('value') / 100) * @duration)
    else
      @$scrubber.slider('value', 0)
  
  moveScrubber: ->
    if @scrubbing and @active_track
      scrubber_position = (@$scrubber.slider('value') / 100) * @duration
      @$time_elapsed.html(@util.readableDuration(scrubber_position))
      @$time_remaining.html("-#{@util.readableDuration(@duration - scrubber_position)}")
      
  toggleMute: ->
    if @last_volume > 0
      if @muted
        @$volume_slider.slider('value', @last_volume)
        @$volume_icon.removeClass 'muted'
        @sm.setVolume(@active_track, @last_volume) if @active_track
        @muted = false
      else
        @last_volume = @$volume_slider.slider 'value'
        @$volume_slider.slider('value', 0)
        @$volume_icon.addClass 'muted'
        @sm.setVolume(@active_track, 0) if @active_track
        @muted = true
    else
      @last_volume = @$volume_slider.slider 'value'
  
  updateVolumeSlider: (value) ->
    if @muted and value > 0
      @$volume_icon.removeClass 'muted'
      @muted = false
    else if !@muted and value == 0
      @$volume_icon.addClass 'muted'
      @muted = true
    @sm.setVolume(@active_track, value)
  
  playTrack: (track_id, time_marker=0) ->
    if time_marker > 0 then @sm.defaultOptions = { from: time_marker } else @sm.defaultOptions = { from: null }
    if track_id != @active_track
      @preload_started = false
      unless @sm_sound = @sm.getSoundById track_id
        @sm_sound = @sm.createSound({
          id: track_id,
          url: "/play-track/#{track_id}",
          whileloading: =>
            this._updateLoadingState(track_id)
          whileplaying: =>
            this._updatePlayerState()
        })
      if @muted
        @sm.setVolume(track_id, 0)
      else
        @sm.setVolume(track_id, @last_volume)
      this._loadTrackInfo(track_id)
      this._fastFadeout(@active_track) if @active_track
      this._updatePauseState()
      @sm.play track_id, {
        onfinish: =>
          this.nextTrack()
      }
      @active_track = track_id
      this.highlightActiveTrack()
      $('body').data 'player-invoked', true
    else
      @util.feedback { 'msg': 'That is already the current track' }
  
  resetPlaylist: (track_id) ->
    $.ajax({
      type: 'post'
      url: '/reset-playlist',
      data: { 'track_id': track_id }
    })
  
  togglePause: ->
    if @sm_sound.paused
      @sm_sound.resume()
      this._updatePauseState()
    else
      if @active_track
        this._fastFadeout(@active_track, true)
        this._updatePauseState false
      else
        this._playRandomShowOrPlaylist()
  
  previousTrack: ->
    if @active_track
      if @sm_sound.position > 3000
        @sm_sound.setPosition 0
      else
        $.ajax({
          url: "/previous-track/#{@active_track}",
          success: (r) =>
            this.playTrack(r.track_id) if r.success
        })
    else
      @util.feedback { 'type': 'alert', 'msg': 'You need to make a playlist to use that button' }
  
  nextTrack: ->
    if @active_track
      $.ajax({
        url: "/next-track/#{@active_track}",
        success: (r) =>
          if r.success
            this.playTrack(r.track_id)
          else
            @util.feedback { 'msg': 'End of playlist reached'}
            this.stopAndUnload(@active_track)
      })
    else
      @util.feedback { 'type': 'alert', 'msg': 'You need to make a playlist to use that button' }
  
  stopAndUnload: (track_id=0) ->
    if @active_track == track_id or track_id == 0
      this._fastFadeout @active_track
      @sm_sound.unload()
      @active_track = ''
      this._updatePlayerDisplay({
        'title': @app_name,
        'duration': 0
      })
      @$scrubber.slider 'value', 0
      @$scrubber.slider 'disable'
      this._updatePauseState false
      @$time_remaining.html ""
      @$time_elapsed.html ""
      $('body').data 'player-invoked', false
  
  highlightActiveTrack: ->
    $('.playable_track').removeClass 'active_track'
    $('.playable_track[data-id="'+@active_track+'"]').removeClass 'highlighted_track'
    $('.playable_track[data-id="'+@active_track+'"]').addClass 'active_track'
    $('#current_playlist>li').removeClass 'active_track'
    $('#current_playlist>li[data-id="'+@active_track+'"]').addClass 'active_track'
  
  _playRandomShowOrPlaylist: ->
    $.ajax({
      url: "/next-track",
      success: (r) =>
        if r.success
          @util.feedback { 'msg': 'Playing current playlist...'}
          this.playTrack(r.track_id)
        else
          $.ajax({
            url: "/random-show",
            success: (r) =>
              if r.success
                @util.feedback { 'msg': 'Playing random show...'}
                @util.navigateTo r.url
                this.resetPlaylist r.track_id
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
          this._updateLoadingState(track_id)
        whileplaying: =>
          this._updatePlayerState()
      })
      @sm.setVolume(track_id, @last_volume)
  
  _loadTrackInfo: (track_id) ->
    $.ajax({
      url: "/track-info/#{track_id}",
      success: (r) =>
        if r.success
          this._updatePlayerDisplay(r)
        else
          @util.feedback { 'type': 'alert', 'msg': 'Error retrieving track info' }
    })
  
  _updatePlayerDisplay: (r) ->
    @duration = r.duration
    if r.title.length > 26 then @$player_title.addClass('long_title') else @$player_title.removeClass('long_title')
    if r.title.length > 50 then r.title = r.title.substring(0, 47) + '...'
    @$player_title.html(r.title)
    @$likes_count.html(r.likes_count)
    @$likes_link.data('id', r.id)
    if r.liked
      @$likes_link.addClass 'liked'
    else
      @$likes_link.removeClass 'liked'
    if @duration == 0
      @$player_detail.html ""
      @$time_elapsed.html ""
      @$time_remaining.html ""
    else
      @$player_detail.html("<a href=\"#{r.show_url}\">#{r.show}</a>&nbsp;&nbsp;&nbsp;<a href=\"#{r.venue_url}\">#{r.venue}</a>&nbsp;&nbsp;&nbsp;<a href=\"#{r.city_url}\">#{r.city}</a>");
  
  _updatePauseState: (playing=true) ->
    if playing
      @$playpause.addClass 'playing'
      @$playlist_button.addClass 'playing'
    else
      @$playpause.removeClass 'playing'
      @$playlist_button.removeClass 'playing'
  
  _updatePlayerState: ->
    unless @scrubbing or @duration == 0
      unless isNaN(@duration) or isNaN(@sm_sound.position)
        # Preload next track if we're close to the end of this one
        if !@preload_started and @duration - @sm_sound.position <= @preload_time
          $.ajax({
            url: "/next-track/#{@active_track}",
            success: (r) =>
              if r.success
                this._preloadTrack(r.track_id)
              # else
              #   alert(r.msg)
          })
          @preload_started = true
        @$scrubber.slider('value', (@sm_sound.position / @duration) * 100)
        @$time_elapsed.html(@util.readableDuration(@sm_sound.position))
        remaining = @duration - @sm_sound.position
        if remaining > 0
          @$time_remaining.html "-#{@util.readableDuration(remaining)}"
        else
          @$time_remaining.html ""  
      else
        @$time_elapsed.html ""
        @$time_remaining.html ""
  
  _updateLoadingState: (track_id) ->
    if @active_track == track_id
      @$feedback.show()
      percent_loaded = Math.floor((@sm_sound.bytesLoaded / @sm_sound.bytesTotal) * 100)
      percent_loaded = 0 if isNaN(percent_loaded)
      @$feedback.html("<i class=\"icon-download\"></i> #{percent_loaded}%")
      if percent_loaded == 100
        @$scrubber.slider 'enable'
        @$feedback.addClass 'done'
        feedback = @$feedback
        setTimeout( ->
          feedback.hide 'fade'
        , 2000)
      else
        @$scrubber.slider 'disable'
        @$feedback.removeClass 'done'
  
  _fastFadeout: (track_id, is_pause=false) ->
    sound = @sm.getSoundById(track_id)
    if @muted or sound.volume == 0
      if is_pause
        sound.pause()
      else
        sound.stop()
      @sm.setVolume(track_id, @$volume_slider.slider('value'))
    else
      if sound.volume < 10 then delta = 1 else delta = 3
      @sm.setVolume(track_id, sound.volume - delta)
      setTimeout( =>
        this._fastFadeout(track_id, is_pause)
      , 10)