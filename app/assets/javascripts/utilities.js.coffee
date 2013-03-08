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
    @$feedback.append("<p class=\"#{css}\" id=\"#{id}\"><i class=\"#{icon}\"></i> #{feedback.msg}</p>")
    setTimeout( ->
      $("##{id}").hide('slide')
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
  
  _requestAlbumResponse: (r, request_url, first_call) ->
    if r.status == 'Ready'
      clearTimeout(@download_poller)
      @$download_modal.modal('hide')
      location.href = r.url
    else if r.status == 'Error'
      clearTimeout(@download_poller)
      @$download_modal.modal('hide')
      that.handleFeedback { 'type': 'alert', 'msg': 'An error occurred while processing your request' }
    else
      if first_call
        clearTimeout(@download_poller)
        @$album_timeout.hide()
        @$download_modal.modal('show')
      else if r.status == 'Timeout'
        @$album_url.html("#{@$app_data.data('base-url')}#{r.url}")
        @$album_timeout.show('slide')
      that = this
      @download_poller = setTimeout( ->
        that.requestAlbum(request_url, false)
      , 3000)
  
  _uniqueID: (length=8) ->
    id = ""
    id += Math.random().toString(36).substr(2) while id.length < length
    id.substr 0, length
