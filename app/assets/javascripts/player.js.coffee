class @Player
  
  constructor: ->
    # @track_list       = []
    @default_volume   = 80
    @last_volume      = @default_volume
    @sm               = soundManager
    @sm_sound         = {}
    @active_track     = ''
    @muted            = false
    @scrubbing        = false
    @duration         = 0
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
      @sm.setPosition(@active_track, (@$scrubber.slider('value') / 100) * @sm_sound.duration)
    else
      @$scrubber.slider('value', 0)
  
  moveScrubber: ->
    if @scrubbing and @active_track
      scrubber_position = (@$scrubber.slider('value') / 100) * @sm_sound.duration
      @$time_elapsed.html(this._readableDuration(scrubber_position))
      @$time_remaining.html("-#{this._readableDuration(@sm_sound.duration - scrubber_position)}")
      
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
      this._loadTrack(track_id)
      this._loadTrackInfo(track_id)
      this._fastFadeout(@active_track) if @active_track
      this._syncPauseState()
      @sm.play track_id, {
        onfinish: ->
          that._handleSoundFinish track_id
      }
      @active_track = track_id
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
      this._syncPauseState()
    else
      if @active_track
        this._fastFadeout(@active_track, true)
        this._syncPauseState(false)
        # @sm_sound.pause()
      else
         alert 'TODO: Select random show and play it from beginning'
  
  previousButton: ->
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
  
  nextButton: ->
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

  _handleSoundFinish: (track_id) ->
    this.nextButton()
  
  # Download a track or load from local if already exists via getSoundById
  _loadTrack: (track_id) ->
    that = this
    unless @sm_sound = @sm.getSoundById track_id
      @sm_sound = @sm.createSound({
        id: track_id,
        url: "/download-track/#{track_id}",
        whileloading: ->
          that._updateLoadingState(@sm_sound)
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
          that._updatePlayerText(r)
        else
          that.handleFeedback { 'type': 'alert', 'msg': 'Error retrieving track info' }
    })
  
  _updatePlayerText: (r) ->
    if r.title.length > 26 then @$player_title.addClass('long_title') else @$player_title.removeClass('long_title')
    @$player_title.html(r.title)
    @$player_detail.html("<a href=\"#{r.show_url}\">#{r.show}</a>&nbsp;&nbsp;&nbsp;<a href=\"#{r.venue_url}\">#{r.venue}</a>&nbsp;&nbsp;&nbsp;<a href=\"#{r.city_url}\">#{r.city}</a>");
  
  _syncPauseState: (playing=true) ->
    if playing
      $('#playpause').addClass('playing')
    else
      $('#playpause').removeClass('playing')
  
  _updatePlayerState: ->
    unless @scrubbing
      @$scrubber.slider('value', (@sm_sound.position / @sm_sound.duration) * 100)
      @$time_elapsed.html(this._readableDuration(@sm_sound.position))
      @$time_remaining.html("-#{this._readableDuration(@sm_sound.duration - @sm_sound.position)}")
  
  _updateLoadingState: (sm_sound) ->
    that = this
    @$feedback.show()
    percent_loaded = Math.floor((@sm_sound.bytesLoaded / @sm_sound.bytesTotal) * 100)
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


