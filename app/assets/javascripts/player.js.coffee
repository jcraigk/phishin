class @Player
  
  constructor: ->
    # @track_list       = []
    @last_volume      = 80
    @sm               = soundManager
    @active_track     = ''
    @sm_sound         = {}
    @muted            = false
    @playing          = false
    @scrubbing        = false
    @duration         = 0
    @$scrubber        = $ '#scrubber'
    @$volume_slider   = $ '#volume_slider'
    @$volume_icon     = $ '#volume_icon'
    @$time_elapsed    = $ '#time_elapsed'
    @$time_remaining  = $ '#time_remaining'
    @scrubber_updater = null

  startScrubbing: ->
    @scrubbing = true
    @$time_elapsed.addClass('scrubbing')
    @$time_remaining.addClass('scrubbing')
  
  stopScrubbing: ->
    @scrubbing = false
    @$time_elapsed.removeClass('scrubbing')
    @$time_remaining.removeClass('scrubbing')
    if @playing
      @sm.setPosition(@active_track, (@$scrubber.slider('value') / 100) * @sm_sound.duration)
    else
      @$scrubber.slider('value', 0)
      
  toggleMute: ->
    if @last_volume > 0
      if @muted
        @$volume_slider.slider('value', @last_volume)
        @$volume_icon.removeClass 'muted'
        @muted = false
      else
        @last_volume = @$volume_slider.slider 'value'
        @$volume_slider.slider('value', 0)
        @$volume_icon.addClass 'muted'
        @muted = true
    else
      @last_volume = @$volume_slider.slider 'value'
    this._updateMuteStatus()
  
  volumeSliderUpdate: (value) ->
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
    unless @sm.getSoundById track_id
      @sm_sound = @sm.createSound({
        id: track_id,
        url: "/download-track/#{track_id}",
        whileplaying: ->
          that._updatePlayerState()
      })
    @sm.stop @active_track if @active_track
    if track_id != @active_track
      @sm.play track_id
      @active_track = track_id
      @playing = true
    else
      @playing = false
      @active_track = null
    this._syncState()
  
  togglePlay: ->
    if @playing
      @sm.stop @active_track
      @playing = false
    else
      if @active_track != ''
        @sm.play @active_track
        @playing = true
      else
        alert 'what to play?'
    this._syncState()
  
  _syncState: ->
    that = this
    if @playing
      $('#playpause').addClass('playing')
    else
      $('#playpause').removeClass('playing')
  
  _updatePlayerState: ->
    unless @scrubbing
      value = (@sm_sound.position / @sm_sound.duration) * 100
      @$scrubber.slider('value', value)
    @$time_elapsed.html(this._readableDuration(@sm_sound.position))
    @$time_remaining.html("-#{this._readableDuration(@sm_sound.duration - @sm_sound.position)}")

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


