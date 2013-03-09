class @Util
  
  constructor: ->
    @page_init          = true
    @$feedback          = $ '#feedback'
    @$app_data          = $ '#app_data'
    @$download_modal    = $ '#download_modal'
    @$album_timeout     = $ '#album_timeout'
    @$album_url         = $ '#album_url'
  
  handleFeedback: (feedback) ->
    if feedback.type == 'notice'
      css = 'feedback_notice'
      icon = 'icon-ok'
    else
      css = 'feedback_alert'
      icon = 'icon-exclamation-sign'
    id = this._uniqueID()
    @$feedback.append "<p class=\"#{css}\" id=\"#{id}\"><i class=\"#{icon}\"></i> #{feedback.msg}</p>"
    setTimeout( ->
      $("##{id}").hide 'slide'
    , 3000)

  followLink: ($el) ->
    @page_init = false
    History.pushState {href: $el.attr 'href'}, @$app_data.data('app-name'), $el.attr 'href'
    window.scrollTo 0, 0
    
  requestAlbum: (request_url, first_call) ->
    that = this
    $.ajax({
      url: '/user-signed-in',
      success: (r) ->
        if r.success
          $.ajax({
            url: request_url,
            dataType: 'json',
            success: (r) ->
              that._requestAlbumResponse(r, request_url, first_call)
          })
        else
          that.handleFeedback { 'type': 'alert', 'msg': 'You must sign in to download MP3s' }
    })
  
  updateCurrentPlaylist: (success_msg) ->
    that = this
    track_ids = []
    duration = 0
    $('#current_playlist > li').each( ->
      track_ids.push $(this).data('track-id')
      duration += parseInt($(this).data('track-duration'))
    )
    $.ajax({
      url: '/update-current-playlist',
      type: 'post',
      data: { 'track_ids': track_ids },
      success: (r) ->
        that.handleFeedback { 'type': 'notice', 'msg': success_msg }
        $('#current_playlist_tracks_label').html("#{track_ids.length} Tracks")
        $('#current_playlist_duration_label').html(that._readableDuration(duration, 'letters'))
    })
  
  _requestAlbumResponse: (r, request_url, first_call) ->
    if r.status == 'Ready'
      clearTimeout @download_poller
      @$download_modal.modal 'hide'
      location.href = r.url
    else if r.status == 'Error'
      clearTimeout @download_poller
      @$download_modal.modal 'hide'
      that.handleFeedback { 'type': 'alert', 'msg': 'An error occurred while processing your request' }
    else
      if first_call
        clearTimeout @download_poller
        @$album_timeout.hide()
        @$download_modal.modal 'show'
      else if r.status == 'Timeout'
        @$album_url.html "#{@$app_data.data('base-url')}#{r.url}"
        @$album_timeout.show 'slide'
      that = this
      @download_poller = setTimeout( ->
        that.requestAlbum(request_url, false)
      , 3000)
  
  _uniqueID: (length=8) ->
    id = ""
    id += Math.random().toString(36).substr(2) while id.length < length
    id.substr 0, length
  
  _readableDuration: (ms, style='colon') ->
    x = Math.floor(ms / 1000)
    seconds = x % 60
    x = Math.floor(x / 60)
    minutes = x % 60
    x = Math.floor(x / 60)
    hours = x % 24
    x = Math.floor(x / 24)
    days = x
    if style == 'letters'
      if days > 0
        "#{days}d #{hours}h #{minutes}m #{seconds}s"
      else if hours > 0
        "#{hours}h #{minutes}m"
      else
        "#{minutes}m #{seconds}s"
    else
      if days > 0
        "%d:%02d:%02d:%02d" % [days, hours, minutes, seconds]
      else if hours > 0
        "%d:%02d:%02d" % [hours, minutes, seconds]
      else
        "%d:%02d" % [minutes, seconds]