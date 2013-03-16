class @Player
  
  constructor: ->
    @sm               = soundManager
    @sm_sound         = {}
    @preload_time     = 40000
    @preload_started  = false
    @active_track     = ''
    @muted            = false
    @scrubbing        = false
    @last_volume      = 100
    @duration         = 0
    @app_name         = $('#app_data').data('app-name')
    @$scrubber        = $ '#scrubber'
    @$volume_slider   = $ '#volume_slider'
    @$volume_icon     = $ '#volume_icon'
    @$time_elapsed    = $ '#time_elapsed'
    @$time_remaining  = $ '#time_remaining'
    @$feedback        = $ '#player_feedback'
    @$player_title    = $ '#player_title'
    @$player_detail   = $ '#player_detail'


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
      @$time_elapsed.html(this._readableDuration(scrubber_position))
      @$time_remaining.html("-#{this._readableDuration(@duration - scrubber_position)}")
      
  toggleMute: ->
    if @last_volume > 0
      if @muted
        @$volume_slider.slider('value', @last_volume)
        @$volume_icon.removeClass 'muted'
        # @sm.setVolume(@active_track, @last_volume) if @active_track
        @muted = false
      else
        @last_volume = @$volume_slider.slider 'value'
        @$volume_slider.slider('value', 0)
        @$volume_icon.addClass 'muted'
        # @sm.setVolume(@active_track, 0) if @active_track
        @muted = true
    else
      @last_volume = @$volume_slider.slider 'value'
  
  updateVolumeSlider: (value) ->
    that = this
    if @muted and value > 0
      @$volume_icon.removeClass 'muted'
      @muted = false
    else if !@muted and value == 0
      @$volume_icon.addClass 'muted'
      @muted = true
    @sm.setVolume(@active_track, value)
  
  playTrack: (track_id) ->
    that = this
    if track_id != @active_track
      @preload_started = false
      unless @sm_sound = @sm.getSoundById track_id
        @sm_sound = @sm.createSound({
          id: track_id,
          url: "/download-track/#{track_id}",
          whileloading: ->
            that._updateLoadingState(track_id)
          whileplaying: ->
            that._updatePlayerState()
        })
        @sm.setVolume(track_id, @last_volume)
      this._loadTrackInfo(track_id)
      this._fastFadeout(@active_track) if @active_track
      this._updatePauseState()
      @sm.play track_id, {
        onfinish: ->
          that.nextTrack()
      }
      @active_track = track_id
      this.highlightActiveTrack()
    else
      alert('already playing')
  
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
        this._updatePauseState(false)
      else
         alert 'TODO: Select random show and play it from beginning'
  
  previousTrack: ->
    that = this
    if @active_track
      if @sm_sound.position > 3000
        @sm_sound.setPosition 0
      else
        $.ajax({
          url: "/previous-track/#{@active_track}",
          success: (r) ->
            if r.success
              that.playTrack(r.track_id)
            else
              alert(r.msg)
        })
    else
      alert 'You need to make a playlist to use this button'
  
  nextTrack: ->
    that = this
    if @active_track
      $.ajax({
        url: "/next-track/#{@active_track}",
        success: (r) ->
          if r.success
            that.playTrack(r.track_id)
          else
            alert(r.msg)
      })
    else
      alert 'You need to make a playlist to use this button'
  
  stopAndUnload: (track_id=0) ->
    if @active_track == track_id or track_id == 0
      this._fastFadeout(@active_track)
      @sm_sound.unload()
      @active_track = ''
      this._updatePlayerDisplay({
        'title': @app_name,
        'duration': 0
      })
  
  highlightActiveTrack: ->
    $('.playable_track').removeClass 'active_track'
    $('.playable_track[data-id="'+@active_track+'"]').addClass 'active_track'
    $('#current_playlist>li').removeClass 'active_track'
    $('#current_playlist>li[data-id="'+@active_track+'"]').addClass 'active_track'
  
  # Download a track or load from local if already exists via getSoundById
  _preloadTrack: (track_id) ->
    alert 'preload'
    that = this
    unless @sm.getSoundById track_id
      @sm.createSound({
        id: track_id,
        url: "/download-track/#{track_id}",
        autoLoad: true,
        whileloading: ->
          that._updateLoadingState(track_id)
        whileplaying: ->
          that._updatePlayerState()
      })
      
      @sm.setVolume(track_id, @last_volume)
  
  _loadTrackInfo: (track_id) ->
    that = this
    $.ajax({
      url: "/track-info/#{track_id}",
      success: (r) ->
        if r.success
          that._updatePlayerDisplay(r)
        else
          that.handleFeedback { 'type': 'alert', 'msg': 'Error retrieving track info' }
    })
  
  _updatePlayerDisplay: (r) ->
    @duration = r.duration
    if r.title.length > 26 then @$player_title.addClass('long_title') else @$player_title.removeClass('long_title')
    @$player_title.html(r.title)
    if @duration == 0
      @$player_detail.html("")
      @$time_elapsed.html("")
      @$time_remaining.html("")
    else
      @$player_detail.html("<a href=\"#{r.show_url}\">#{r.show}</a>&nbsp;&nbsp;&nbsp;<a href=\"#{r.venue_url}\">#{r.venue}</a>&nbsp;&nbsp;&nbsp;<a href=\"#{r.city_url}\">#{r.city}</a>");
  
  _updatePauseState: (playing=true) ->
    if playing
      $('#playpause').addClass('playing')
    else
      $('#playpause').removeClass('playing')
  
  _updatePlayerState: ->
    that = this
    unless @scrubbing or @duration == 0
      unless isNaN(@duration) or isNaN(@sm_sound.position)
        # Preload next track if we're close to the end of this one
        if !@preload_started and @duration - @sm_sound.position <= @preload_time
          $.ajax({
            url: "/next-track/#{@active_track}",
            success: (r) ->
              if r.success
                that._preloadTrack(r.track_id)
              else
                alert(r.msg)
          })
          @preload_started = true

        @$scrubber.slider('value', (@sm_sound.position / @duration) * 100)
        @$time_elapsed.html(this._readableDuration(@sm_sound.position))
        remaining = @duration - @sm_sound.position
        if remaining > 0
          @$time_remaining.html "-#{this._readableDuration(remaining)}"
        else
          @$time_remaining.html ""  
      else
        @$time_elapsed.html ""
        @$time_remaining.html ""
  
  _updateLoadingState: (track_id) ->
    if @active_track == track_id
      that = this
      @$feedback.show()
      percent_loaded = Math.floor((@sm_sound.bytesLoaded / @sm_sound.bytesTotal) * 100)
      percent_loaded = 0 if isNaN(percent_loaded)
      @$feedback.html("<i class=\"icon-download\"></i> #{percent_loaded}%")
      if percent_loaded == 100
        @$feedback.addClass('done')
        feedback = @$feedback
        setTimeout( ->
          feedback.hide('fade')
        , 2000)
      else
        @$feedback.removeClass('done')
  
  _fastFadeout: (track_id, is_pause=false) ->
    that = this
    sound = @sm.getSoundById(track_id)
    if sound.muted or sound.volume == 0
      if is_pause
        sound.pause()
      else
        sound.stop()
      @sm.setVolume(track_id, @$volume_slider.slider('value'))
    else
      if sound.volume < 10 then delta = 1 else delta = 3
      @sm.setVolume(track_id, sound.volume - delta)
      setTimeout( ->
        that._fastFadeout(track_id, is_pause)
      , 10)

  _readableDuration: (ms) ->
    x = Math.floor(ms / 1000)
    seconds = x % 60
    seconds_with_zero = "#{if seconds < 10 then '0' else '' }#{seconds}"
    x = Math.floor(x / 60)
    minutes = x % 60
    minutes_with_zero = "#{if minutes < 10 then '0' else '' }#{minutes}"
    x = Math.floor(x / 60)
    hours = x % 24
    hours_with_zero = "#{if hours < 10 then '0' else '' }#{hours}"
    x = Math.floor(x / 24)
    days = x
    if days > 0
      "#{days}::#{hours}:#{minutes_with_zero}:#{seconds_with_zero}"
    else if hours > 0
      "#{hours}:#{minutes_with_zero}:#{seconds_with_zero}"
    else
      "#{minutes}:#{seconds_with_zero}"


