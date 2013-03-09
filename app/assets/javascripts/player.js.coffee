class @Player
  
  constructor: ->
    @muted            = false
    @last_volume      = 70
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
  
  volumeSliderUpdate: (value) ->
    that = this
    if @muted and value > 0
      @$volume_icon.removeClass 'muted'
      @muted = false
    else if !@muted and value == 0
      @$volume_icon.addClass 'muted'
      @muted = true
      