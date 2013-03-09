class @Player
  
  constructor: ->
    @sm               = soundManager
    @active_track     = ''
    @muted            = false
    @playing          = false
    @duration         = 0
    @$scrubber        = $ '#scrubber'
    @$volume_slider   = $ '#volume_slider'
    @$volume_icon     = $ '#volume_icon'
  
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
  
  setSoundPosition: (value) ->
    @sm.setPosition(@active_track, Math.floor((value * @duration) / 100))
  
  playTrack: (track_id) ->
    unless @sm.getSoundById track_id
      @sm.createSound({
        id: track_id,
        url: "/download-track/#{track_id}"
      })
    @sm.stop @active_track if @active_track
    @sm.play track_id
    @active_track = track_id
    @playing = true
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
    if @playing
      $('#playpause').addClass('testclass')
    else
      $('#playpause').removeClass('testclass')