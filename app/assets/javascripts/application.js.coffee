//= require jquery
//= require jquery_ujs
//= require twitter/bootstrap
//= require jquery.ui.slider
//= require soundmanager
//= require util
//= require_tree .

# Generic namespace
Ph = {}

$ ->
  
  # Instantiate stuff
  Ph.Util = new Util
  
  # Page elements
  $notice         = $ '.feedback_notice'
  $alert          = $ '.feedback_alert'
  $ajax_overlay   = $ '#ajax_overlay'
  $page           = $ '#page'
  
  ###############################################
  # Handle feedback initial state on DOM load
  if $notice.html() != ''
    $notice.show 'slide'
    setTimeout( ->
      $notice.hide 'slide'
    , 3000)
  else
    $notice.hide()
  if $alert.html() != ''
    $falert.show 'slide'
    setTimeout( ->
      $alert.hide 'slide'
    , 3000)
  else
    $alert.hide()
  
  ###############################################
  # Prepare history.js
  History = window.History
  return false if !History.enabled
  History.Adapter.bind window, 'statechange', ->
    State = History.getState()
    History.log State.data, State.title, State.url
  History.Adapter.bind window, 'popstate', ->   
    state = window.History.getState()
    if state.data.href != undefined and !Ph.Util.page_init
      $ajax_overlay.css 'visibility', 'visible'
      $page.load(
        state.data.href, (response, status, xhr) ->
          alert("ERROR\n\n"+response) if status == 'error'
      )
      $ajax_overlay.css 'visibility', 'hidden'

  # Click a link to load context via ajax
  $(document).on 'click', 'a', ->
    unless $(this).hasClass('non-remote')
      Ph.Util.followLink $(this) if $(this).attr('href') != "#" and $(this).attr('href') != 'null'
      false

  ###############################################
    
  # Click to download an individual track
  $(document).on 'click', 'a.download', ->
    data_url = $(this).data('url')
    $.ajax({
      url: '/user-signed-in',
      success: (r) ->
        if r.success
          location.href = data_url if data_url
        else
          Ph.Util.handleFeedback { 'type': 'alert', 'msg': 'You must sign in to download MP3s' }
    })
  
  # Click to download a set of tracks
  $(document).on 'click', 'a.download-album', ->
    Ph.Util.requestAlbum $(this).data('url'), true
    
  # Stop polling server when download modal is hidden
  $('#download_modal').on 'hidden', ->
    Ph.Util.StopDownloadPoller

  ###############################################
  
  # Scrubber slider (jQuery UI Slider)
  $('#scrubber').slider({
      animate: "fast",
      range: "min"
  })
  
  # Like tooltip
  $('.likes_large a').tooltip({
    placement: 'bottom',
    delay: { show: 500, hide: 0 }
  })
  $('.likes_small > a').tooltip({
    delay: { show: 500, hide: 0 }
  })
  
  # Click a Like to submit to server
  $(document).on 'click', '.like_toggle', ->
    $this = $(this)
    $.ajax({
      type: 'post',
      url: '/toggle-like',
      data: { 'likable_type': $this.data('type'), 'likable_id': $this.data('id') }
      dataType: 'json',
      success: (r) ->
        if r.success
          if r.liked then $this.addClass('liked') else $this.removeClass('liked')
          Ph.Util.handleFeedback({ 'type': 'notice', 'msg': r.msg })
          $this.siblings('span').html(r.likes_count)
        else
          Ph.Util.handleFeedback({ 'type': 'alert', 'msg': r.msg })
    })
  
  # Rollover year to reveal number of shows
  $(document).on 'mouseover', '.year_list > li', ->
    $(this).find('h2').css 'visibility', 'visible'
  $(document).on 'mouseout', '.year_list > li', ->
    $(this).find('h2').css 'visibility', 'hidden'

  # Rollover item list to reveal context button
  $(document).on 'mouseover', '.item_list > li', ->
    $(this).find('.btn_context').css 'visibility', 'visible'
  $(document).on 'mouseout', '.item_list > li', ->
    $(this).find('.btn_context').css 'visibility', 'hidden'

  # Rollover header to reveal context button
  $(document).on 'mouseover', '#header', ->
    $(this).find('.btn_context').css 'visibility', 'visible'
  $(document).on 'mouseout', '#header', ->
    $(this).find('.btn_context').css 'visibility', 'hidden'
    
  # Follow links in .year_list
  $(document).on 'click', '.year_list > li', ->
    Ph.Util.followLink $(this).find 'a'
  
  # Follow h1>a links in .item_list.clickable > li
  $(document).on 'click', '.item_list > li', ->
    if $(this).parent('ul').hasClass 'clickable'
      Ph.Util.followLink $(this).children('h2').find 'a'
  
  # Share links bring up a modal to display a url
  $(document).on 'click', '.share', ->
    $('#share_url').html("<p>"+$('#app_data').data('base-url')+$(this).data('url')+"</p>")
    $('#share_modal').modal('show')
    