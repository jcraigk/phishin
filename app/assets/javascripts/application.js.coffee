//= require jquery
//= require jquery_ujs
//= require twitter/bootstrap
//= require jquery.ui.slider
//= require jquery.ui.sortable
//= require jquery.ui.datepicker
//= require soundmanager
//= require history
//= require util
//= require player
//= require map

# Generic namespace
@App = {}

$ ->
  
  window.location.href = '/mobile-unsupported' if/Android|webOS|iPhone|iPad|iPod|BlackBerry/i.test(navigator.userAgent)
  
  # Instantiate stuff
  App.Util         = new Util
  App.Player       = new Player
  App.Map          = new Map
  
  # Page elements
  $notice         = $ '.feedback_notice'
  $alert          = $ '.feedback_alert'
  $ajax_overlay   = $ '#ajax_overlay'
  $page           = $ '#page'

  ###############################################
  # Prepare history.js
  ###############################################
  History = window.History
  return false if !History.enabled
  History.Adapter.bind window, 'statechange', ->
    State = History.getState()
    History.log State.data, State.title, State.url
  History.Adapter.bind window, 'popstate', ->
    state = window.History.getState()
    if state.data.href != undefined and !App.Util.page_init
      $ajax_overlay.css 'visibility', 'visible'
      $page.html ''
      $page.load(
        state.data.href, (response, status, xhr) ->
          alert("ERROR\n\n"+response) if status is 'error'
          $ajax_overlay.css 'visibility', 'hidden'
          
          # Re-render twitter button(s)
          twttr.widgets.load() if twttr?
                    
          # Report href to Google Analytics
          _gaq.push([ '_trackPageview', state.data.href ]);
          
          # Auto-scroll and highlight track anchor if present
          if anchor = state.data.href.split("/")[2]
            $('body').attr 'data-anchor', anchor
          else
            $('body').attr 'data-anchor', ''
          App.Player.onReady() # For scrolling to and auto-playing a track
          App.Player.highlightActiveTrack() # For highlighting current track in a list
          
          # Map
          if state.data.href.substr(0,4) is '/map'
            App.Map.initMap()
            term = $('#map_search_term').val()
            distance = $('#map_search_distance').val()
            App.Map.handleSearch(term, distance) if term and distance
          
          # Playlist
          else if state.data.href.substr(0,9) is '/playlist'
            # Sortable playlist AJAX load
            $('#current_playlist').sortable({
              placeholder: "ui-state-highlight",
              update: ->
                App.Util.updateCurrentPlaylist 'Track moved in playlist'
            })
      )

  ###############################################
  # Reload initial page for history's sake if not a devise route
  ###############################################
  path_segment = window.location.pathname.split('/')[1]
  if path_segment isnt 'users'
    $page.html ''
    App.Util.navigateTo(window.location.pathname)
  
  ###############################################
  # Handle feedback on DOM load
  ###############################################
  if $notice and $notice.html() != ''
    $notice.show 'slide'
    setTimeout( ->
      $notice.hide 'slide'
    , 3000)
  else
    $notice.hide()
  if $alert and $alert.html() != ''
    $alert.show 'slide'
    setTimeout( ->
      $alert.hide 'slide'
    , 3000)
  else
    $alert.hide()
  
  ###############################################
  # Auto-play or scroll to and play anchor
  ###############################################
  soundManager.onready( ->
    App.Player.onReady()
  )

  ###############################################
  # DOM interactions
  ###############################################
  
  # Click a link to load page via ajax
  $(document).on 'click', 'a', ->
    unless $(this).hasClass('non-remote')
      App.Util.followLink $(this) if $(this).attr('href') != "#" and $(this).attr('href') != 'null'
      false
  
  # Close dropdown menu after clicking link within
  # Following causes issues with subsequent usage of that dropdown
  # $(document).on 'click', '.dropdown-menu a', (e) ->
  #   $(this).parents('.dropdown-menu').dropdown('toggle')
  
  # Submit new user
  $(document).on 'submit', '#new_user', (e) ->
    $('#new_user_container').fadeTo('fast', 0.5)
    $('#new_user_submit_btn').val('Processing...')

  # Focus => remove other value
  $(document).on 'focus', '#search_term', (e) ->
    $('#search_date').val ''
  $(document).on 'focus', '#search_date', (e) ->
    $('#search_term').val ''
  
  # Submit search
  $(document).on 'click', '#search_submit', (e) ->
    App.Util.navigateTo '/search?date='+$('#search_date').val()+'&term='+encodeURI($('#search_term').val())
  $(document).on 'keypress', '#search_date', (e) ->
    App.Util.navigateTo '/search?date='+$('#search_date').val()+'&term='+encodeURI($('#search_term').val()) if e.which is 13
  $(document).on 'keypress', '#search_term', (e) ->
    App.Util.navigateTo '/search?date='+$('#search_date').val()+'&term='+encodeURI($('#search_term').val()) if e.which is 13
    
  ###############################################

  # Submit map search
  term = $('#map_search_term').val()
  distance = $('#map_search_distance').val()
  App.Map.handleSearch(term, distance) if term and distance
  $(document).on 'click', '#map_search_submit', (e) ->
    App.Util.navigateToRefreshMap()
  $(document).on 'keypress', '#map_search_term', (e) ->
    App.Util.navigateToRefreshMap() if e.which is 13
  $(document).on 'keypress', '#map_search_distance', (e) ->
    App.Util.navigateToRefreshMap() if e.which is 13
  $(document).on 'keypress', '#map_date_start', (e) ->
    App.Util.navigateToRefreshMap() if e.which is 13
  $(document).on 'keypress', '#map_date_stop', (e) ->
    App.Util.navigateToRefreshMap() if e.which is 13

  ###############################################
  
  # Sortable playlist DOM load
  $('#current_playlist').sortable({
    placeholder: "ui-state-highlight",
    update: ->
      App.Util.updateCurrentPlaylist 'Track moved in playlist'
  })
  
  # Remove track from playlist
  $(document).on 'click', '.playlist_remove_track', (e) ->
    track_id = $(this).parents('li').data('id')
    $(this).parents('li').remove()
    if $('#current_playlist').children('li').size() is 0
      App.Util.followLink $('#clear_playlist')
      App.Player.stopAndUnload()
    else
      App.Util.updateCurrentPlaylist 'Track removed from playlist'
      App.Player.stopAndUnload track_id
  
  # Add track to playlist
  $(document).on 'click', '.playlist_add_track', (e) ->
    track_id = $(this).data('id')
    $.ajax({
      type: 'post',
      url: '/add-track',
      data: { 'track_id': track_id}
      success: (r) ->
        if r.success
          App.Util.feedback { msg: 'Track added to playlist' }
        else
          App.Util.feedback { type: 'alert', msg: r.msg }
    })
  
  # Add show to playlist
  $(document).on 'click', '.playlist_add_show', (e) ->
    show_id = $(this).data('id')
    $.ajax({
      type: 'post',
      url: '/add-show',
      data: { 'show_id': show_id}
      success: (r) ->
        if r.success
          App.Util.feedback { msg: r.msg }
        else
          App.Util.feedback { type: 'alert', msg: r.msg }
    })
  
  # Clear playlist stops and unloads current sound
  $(document).on 'click', '#clear_playlist', (e) ->
    App.Player.stopAndUnload()
  
  # Playlist Option change
  $(document).on 'change', '.playlist_option', (e) ->
    $.ajax({
      type: 'post',
      url: '/submit-playlist-options',
      data: {
        'loop': $('#loop_checkbox').prop('checked'),
        'randomize': $('#randomize_checkbox').prop('checked')
      }
      success: (r) ->
        if r.success
          App.Util.feedback { msg: 'Playlist options saved' }
        else
          App.Util.feedback { type: 'alert', msg: r.msg }
    })
  
  ###############################################
  
  # Click a track to play it
  $(document).on 'click', '.playable_track', (e) ->
    App.Player.resetPlaylist $(this).data('id')
    App.Player.playTrack $(this).data('id')
  
  # Click Play in a context menu to play the track
  $(document).on 'click', '.context_play_track', (e) ->
    App.Player.resetPlaylist $(this).data('id')
    App.Player.playTrack $(this).data('id')

  # Click the Play/Pause button
  $(document).on 'click', '#playpause', (e) ->
    App.Player.togglePause()
  
  # Click the Previous button
  $(document).on 'click', '#previous', (e) ->
    App.Player.previousTrack()

  # Click the Next button
  $(document).on 'click', '#next', (e) ->
    App.Player.nextTrack()
    
  # Scrubber (jQuery UI slider)
  $('#scrubber').slider({
    animate: 'fast',
    range: 'min',
    max: 100,
    value: 0,
    create: ->
      # Fix knob in Safari (offset vertically by 1 px)
      if (navigator.userAgent.indexOf('Safari') != -1 && navigator.userAgent.indexOf('Chrome') is -1)
        $('#scrubber .ui-slider-handle').css('margin-top', '3px')
    start: ->
      App.Player.startScrubbing()
    stop: ->
      App.Player.stopScrubbing()
    slide: ->
      App.Player.moveScrubber()
  }).slider('disable')
  
  # Volume slider (jQuery UI slider)
  $('#volume_slider').slider({
    animate: 'fast',
    range: 'min',
    max: 100,
    value: 100,
    slide: ->
      App.Player.updateVolumeSlider $(this).slider('value')
  })
  
  # Loop / Randomize controls
  $(document).on 'click', '#loop_checkbox', (e) ->
    $(this).attr('checked', !$(this).attr('checked'))
    e.stopPropagation()
  $(document).on 'click', '#randomize_checkbox', (e) ->
    $(this).attr('checked', !$(this).attr('checked'))
    e.stopPropagation()
    
  # Toggle mute
  $(document).on 'click', '#volume_icon', (e) ->
    App.Player.toggleMute()
    e.stopPropagation()
  
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
          App.Util.feedback { alert: 'You must sign in to download MP3s' }
    })
  
  # Click to download a set of tracks
  $(document).on 'click', 'a.download-album', ->
    App.Util.requestAlbum $(this).data('url'), true
    
  # Stop polling server when download modal is hidden
  $('#download_modal').on 'hidden', ->
    App.Util.StopDownloadPoller

  ###############################################
  
  # Hover on player title to reveal Like toggle
  $(document).on 'mouseover', '#player_title_container', (e) ->
    if App.Player.invoked()
      $('#player_title').css 'display', 'none'
      $('#player_likes_container').css 'display', 'inline-block'
  $(document).on 'mouseout', '#player_title_container', (e) ->
    if App.Player.invoked()
      $('#player_likes_container').css 'display', 'none'
      $('#player_title').css 'display', 'block'
  
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
          App.Util.feedback({ msg: r.msg })
          if r.liked then $this.addClass('liked') else $this.removeClass('liked')
          $this.siblings('span').html r.likes_count
          # Update other instances of this track's Like controls
          $('.like_toggle[data-type="track"]').each( ->
            unless $this.data('id') != $(this).data('id') or $this.is $(this)
              if r.liked then $(this).addClass 'liked' else $(this).removeClass 'liked'
              $(this).siblings('span').html r.likes_count
          )
        else
          App.Util.feedback { alert: r.msg }
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
    App.Util.followLink $(this).find 'a'
  
  # Follow h1>a links in .item_list.clickable > li
  $(document).on 'click', '.item_list > li', (e) ->
    if $(this).parent('ul').hasClass 'clickable'
      unless e.target.target and e.target.target is '_blank'
        App.Util.followLink $(this).children('h2').find 'a'
  
  # Share links bring up a modal to display a url
  $(document).on 'click', '.share', ->
    $('#share_url').html("<p>"+$('body').data('base-url')+$(this).data('url')+"</p>")
    $('#share_modal').modal('show')
    