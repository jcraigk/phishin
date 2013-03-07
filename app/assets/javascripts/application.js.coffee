//= require jquery
//= require jquery_ujs
//= require twitter/bootstrap
//= require history
//= require_tree .

# Generic namespace
Ph = {}

Ph.uniqueID = (length=8) ->
  id = ""
  id += Math.random().toString(36).substr(2) while id.length < length
  id.substr 0, length

Ph.handleFeedback = (feedback) ->
  if feedback.type == 'notice'
    css = 'feedback_notice'
    icon = 'icon-ok'
  else
    css = 'feedback_alert'
    icon = 'icon-exclamation-sign'
  id = Ph.uniqueID()
  $('#feedback').append("<p class=\"#{css}\" id=\"#{id}\"><i class=\"#{icon}\"></i> #{feedback.msg}</p>")
  setTimeout( ->
    $("##{id}").hide('slide')
  , 3000)

page_init = true
Ph.followLink = ($el) ->
  page_init = false
  # console.log $el
  History.pushState {href: $el.attr 'href'}, $('#app_data').data('app-name'), $el.attr 'href'
  window.scrollTo 0, 0

Ph.requestAlbum = (request_url, first_call) ->
  $.ajax({
    url: '/user-signed-in',
    success: (r) ->
      if r.success
        $.ajax({
          url: request_url,
          dataType: 'json',
          success: (r) ->
            if r.status == 'Ready'
              clearTimeout(Ph.download_poller)
              $('#download_modal').modal('hide')
              location.href = r.url
            else if r.status == 'Error'
              clearTimeout(Ph.download_poller)
              $('#download_modal').modal('hide')
              Ph.handleFeedback { 'type': 'alert', 'msg': 'An error occurred while processing your request' }
            else
              if first_call
                $('#album_timeout').hide()
                $('#download_modal').modal('show')
              else if r.status == 'Timeout'
                $('#album_url').html("#{$('#app_data').data('base-url')}#{r.url}")
                $('#album_timeout').show('slide')
              Ph.download_poller = setTimeout( ->
                Ph.requestAlbum(request_url, false)
              , 3000)
        })
      else
        Ph.handleFeedback { 'type': 'alert', 'msg': 'You must sign in to download MP3s' }
  })
  


$ ->
  
  ###############################################
  # Handle feedback initial state on DOM load
  if $('.feedback_notice').html() != ''
    $('.feedback_notice').show('slide')
    setTimeout( ->
      $('.feedback_notice').hide('slide')
    , 3000)
  else
    $('.feedback_notice').hide()
  if $('.feedback_alert').html() != ''
    $('.feedback_alert').show('slide')
    setTimeout( ->
      $('.feedback_alert').hide('slide')
    , 3000)
  else
    $('.feedback_alert').hide()
  
  ###############################################
  # Prepare history.js
  History = window.History
  return false if !History.enabled
  History.Adapter.bind window, 'statechange', ->
    State = History.getState()
    History.log State.data, State.title, State.url
  History.Adapter.bind window, 'popstate', ->   
    state = window.History.getState()
    # console.log state
    if state.data.href != undefined and !page_init
      $('#ajax_overlay').css 'visibility', 'visible'
      $('#page').load(
        state.data.href, (response, status, xhr) ->
          alert("ERROR\n\n"+response) if status == 'error'
      )
      $('#ajax_overlay').css 'visibility', 'hidden'

  # Click a link to load context via ajax
  $(document).on 'click', 'a', ->
    unless $(this).hasClass('non-remote')
      Ph.followLink $(this) if $(this).attr('href') != "#" and $(this).attr('href') != 'null'
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
          Ph.handleFeedback { 'type': 'alert', 'msg': 'You must sign in to download MP3s' }
    })
  
  # Click to download a set of tracks
  $(document).on 'click', 'a.download-album', ->
    Ph.requestAlbum $(this).data('url'), true
    
  # Stop polling server when download modal is hidden
  $('#download_modal').on 'hidden', ->
    clearTimeout(Ph.download_poller)

  ###############################################
  
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
          Ph.handleFeedback({ 'type': 'notice', 'msg': r.msg })
          $this.siblings('span').html(r.likes_count)
        else
          Ph.handleFeedback({ 'type': 'alert', 'msg': r.msg })
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
    Ph.followLink $(this).find 'a'
  
  # Follow h1>a links in .item_list.clickable > li
  $(document).on 'click', '.item_list > li', ->
    if $(this).parent('ul').hasClass 'clickable'
      Ph.followLink $(this).children('h2').find 'a'
  
  # Share links bring up a modal to display a url
  $(document).on 'click', '.share', ->
    $('#share_url').html("<p>"+$('#app_data').data('base-url')+$(this).data('url')+"</p>")
    $('#share_modal').modal('show')
    