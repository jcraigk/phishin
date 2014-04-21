//= require jquery
//= require jquery_ujs
//= require twitter/bootstrap
//= require jquery.ui.slider
//= require jquery.ui.sortable
//= require jquery.ui.datepicker
//= require jquery.cookie
//= require soundmanager
//= require history.min
//= require classes/detector
//= require classes/util
//= require classes/player
//= require classes/playlist
//= require classes/map
//= require spin.min

# Generic namespace
@App = {}

$ ->
  
  ###############################################
  # Init
  ###############################################

  App.Detector     = null       # delay Detector creation until body load (PhishOD track ID detection)
  App.Util         = new Util
  App.Player       = new Player
  App.Playlist     = new Playlist
  App.Map          = new Map
  
  ###############################################
  # Assignments
  ###############################################

  $notice         = $ '.feedback_notice'
  $alert          = $ '.feedback_alert'
  $ajax_overlay   = $ '#ajax_overlay'
  $page           = $ '#page'
  
  ###############################################
  # Helpers
  ###############################################
  
  handleHistory = ->
    state = window.History.getState()
    if state.data.href != undefined and !App.Util.page_init
      $ajax_overlay.css 'visibility', 'visible'
      $page.html ''
      $page.load(
        state.data.href, (response, status, xhr) ->
          # App.Util.showHTMLError(xhr.status + " " + xhr.statusText)
          App.Util.showHTMLError("ERROR\n\n"+response) if status is 'error'
          
          # alert("ERROR\n\n"+response) if status is 'error'
          $ajax_overlay.css 'visibility', 'hidden'
          
          # Scroll to proper position (not currently working)
          window.scrollTo 0, App.Util.historyScrollStates[state.id] if App.Util.historyScrollStates[state.id]
          
          # Tooltips
          # $('[title]').tooltip()
                    
          # Report href to Google Analytics
          _gaq.push([ '_trackPageview', state.data.href ]);
          
          # Auto-scroll and highlight track anchor if present
          if state.data.href.substr(0,6) != '/play/' and path = state.data.href.split("/")[2]
            match = /^([^\?]+)\??(.+)?$/.exec(path)
            $('body').attr 'data-anchor', match[1]
          else
            $('body').attr 'data-anchor', ''
          App.Player.onReady() # For scrolling to and auto-playing a track
          App.Player.highlightActiveTrack(true) # For highlighting current track in a list, scrollTo = true

          # For detecting browsers/platforms
          App.Detector = new Detector
          
          # Google Map
          if state.data.href.substr(0,4) is '/map'
            App.Map.initMap()
            term = $('#map_search_term').val()
            distance = $('#map_search_distance').val()
            App.Map.handleSearch(term, distance) if term and distance
          
          # Playlist
          else if state.data.href.substr(0,9) is '/playlist' or state.data.href.substr(0,6) is '/play/'
            App.Playlist.initPlaylist()
      )

  ###############################################
  # Prepare history.js
  ###############################################
  History = window.History
  return false if !History.enabled
  History.Adapter.bind window, 'statechange', ->
    handleHistory()

  ###############################################
  # Load initial page if not an exempt route
  ###############################################
  path_segment = window.location.pathname.split('/')[1]
  if path_segment isnt 'users'
    $page.html ''
    match = /^http:\/\/(.+)$/.exec(window.location)
    href = match[1].substr(match[1].indexOf('/'), match[1].length - 1)
    App.Util.navigateTo(href)
    handleHistory()  # Need to call this explicitly on page load (to keep Firefox in the mix)
  
  ###############################################
  # Handle feedback on DOM load (for Devise)
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
  soundManager.setup
    url: '/assets/'
    useHTML5Audio: true
    preferFlash: false
    debugMode: true
  soundManager.onready( ->
    App.Player.onReady()
  )

  ###############################################
  # DOM interactions
  ###############################################
  
  # Click Phish On Demand app callout
  $(document).on 'click', '#phishod_callout', ->
    window.location = 'https://itunes.apple.com/us/app/phish-on-demand-all-phish/id672139018'
  
  # Click a link to load page via ajax
  .on 'click', 'a', ->
    unless $(this).hasClass('non-remote')
      App.Util.followLink $(this) if $(this).attr('href') != "#" and $(this).attr('href') != 'null'
      false
  
  # Close dropdown menu after clicking link within
  # Following causes issues with subsequent usage of that dropdown
  # $(document).on 'click', '.dropdown-menu a', (e) ->
    # $(this).parents('.dropdown-menu').dropdown().toggle()
    # $(this).parents('.dropdown-menu').css('left', -3000)
    # $(this).parents('.dropdown-menu').css('top', -3000)

  ###############################################
  
  # Submit new user
  .on 'submit', '#new_user', (e) ->
    $('#new_user_container').fadeTo('fast', 0.5)
    $('#new_user_submit_btn').val('Processing...')
    
  ###############################################

  # Submit search
  .on 'keypress', '#search_term', (e) ->
    if e.which is 13
      App.Util.navigateTo '/search?term='+encodeURI($('#search_term').val()) 
      $(this).val ''
      $(this).blur()
    
  ###############################################

  # Submit map search
  term = $('#map_search_term').val()
  distance = $('#map_search_distance').val()
  App.Map.handleSearch(term, distance) if term and distance
  .on 'click', '#map_search_submit', (e) ->
    App.Util.navigateToRefreshMap()
  .on 'keypress', '#map_search_term', (e) ->
    App.Util.navigateToRefreshMap() if e.which is 13
  .on 'keypress', '#map_search_distance', (e) ->
    App.Util.navigateToRefreshMap() if e.which is 13
  .on 'keypress', '#map_date_start', (e) ->
    App.Util.navigateToRefreshMap() if e.which is 13
  .on 'keypress', '#map_date_stop', (e) ->
    App.Util.navigateToRefreshMap() if e.which is 13

  ###############################################
  
  # Playlist stuff
  $(document)
  .on 'click', '#playlist_mode_btn', (e) ->
    App.Player.togglePlaylistMode()
  .on 'click', '#playlist_button', ->
    App.Util.navigateTo $(this).data('url')
  .on 'click', '#share_playlist_btn', ->
    App.Playlist.handleShareModal()
  .on 'blur', '#playlist_name_input', (e) ->
    $('#playlist_slug_input').val App.Util.stringToSlug($(this).val())
  .on 'click', '#save_playlist_btn', (e) ->
    App.Playlist.handleSaveModal()
  .on 'click', '#duplicate_playlist_btn', (e) ->
    App.Playlist.handleDuplicateModal()
  .on 'click', '#save_playlist_submit', (e) ->
    App.Playlist.savePlaylist()
  .on 'click', '#delete_playlist_btn', (e) ->
    if confirm 'Are you sure you want to permanently delete this playlist?'
      App.Playlist.deletePlaylist()
  .on 'click', '#bookmark_playlist_btn', (e) ->
    App.Playlist.bookmarkPlaylist()
    $('#bookmark_playlist_btn').hide()
  .on 'click', '#unbookmark_playlist_btn', (e) ->
    App.Playlist.unbookmarkPlaylist()
    $('#unbookmark_playlist_btn').hide()
  .on 'click', '#clear_playlist_btn', (e) ->
    if confirm 'Are you sure you want to remove all tracks from your active playlist?'
      App.Playlist.clearPlaylist false
  .on 'click', '.playlist_add_track', (e) ->
    App.Playlist.addTrackToPlaylist $(this).data('id')
  .on 'click', '.playlist_add_show', (e) ->
    App.Playlist.addShowToPlaylist $(this).data('id')
  .on 'click', '.playlist_remove_track', (e) ->
    $(this).parents('li').remove()
    App.Playlist.removeTrackFromPlaylist $(this).parents('li').data('id')
  .on 'change', '.playlist_option', (e) ->
    App.Playlist.handleOptionChange()
  
  ###############################################
  
  # Click a track to play it
  .on 'click', '.playable_track', (e) ->
    clicked_from_playlist = $(this).parents('#active_playlist').length > 0
    if App.Player.playlist_mode and !clicked_from_playlist
      App.Playlist.addTrackToPlaylist $(this).data('id')
    else
      App.Player.playTrack $(this).data('id')
      unless clicked_from_playlist
        App.Player.setCurrentPlaylist $(this).data('id')
  
  # Click Play in a context menu to play the track
  .on 'click', '.context_play_track', (e) ->
    App.Player.setCurrentPlaylist $(this).data('id')
    App.Player.playTrack $(this).data('id')

  # Click the Play/Pause button
  .on 'click', '#playpause', (e) ->
    App.Player.togglePause()
  
  # Click the Previous button
  .on 'click', '#previous', (e) ->
    App.Player.previousTrack()

  # Click the Next button
  .on 'click', '#next', (e) ->
    App.Player.nextTrack()
    
  # Scrubber (jQuery UI slider)
  $('#scrubber').slider({
    animate: 'fast',
    range: 'min',
    max: 100,
    value: 0,
    create: ->
      # Fix knob in Safari and Firefox/Mac (offset vertically by 1 px)
      if (navigator.userAgent.indexOf('Safari') != -1 && navigator.userAgent.indexOf('Chrome') is -1)
        $('#scrubber .ui-slider-handle').css('margin-top', '3px')
      else if (navigator.userAgent.indexOf('Firefox') != -1 && navigator.userAgent.indexOf('Chrome') is -1)
        $('#scrubber .ui-slider-handle').css('margin-top', '4px')
      else
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
  .on 'click', '#randomize_checkbox', (e) ->
    $(this).attr('checked', !$(this).attr('checked'))
    e.stopPropagation()
    
  # Toggle mute
  .on 'click', '#volume_icon', (e) ->
    App.Player.toggleMute()
    e.stopPropagation()
  
  ###############################################

  # Click to download an individual track
  .on 'click', 'a.download', ->
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
  .on 'click', 'a.download-album', ->
    App.Util.requestAlbum $(this).data('url'), true
    
  # Stop polling server when download modal is hidden
  $('#download_modal').on 'hidden', ->
    App.Util.StopDownloadPoller

  ###############################################
  
  # Hover on player title to reveal Like toggle
  $(document).on 'mouseover', '#player_title_container', (e) ->
    if App.Player.invoked
      $('#player_title').css 'display', 'none'
      $('#player_likes_container').css 'display', 'inline-block'
  .on 'mouseout', '#player_title_container', (e) ->
    if App.Player.invoked
      $('#player_likes_container').css 'display', 'none'
      $('#player_title').css 'display', 'block'
  
  # Like tooltip
  # $('.likes_large a').tooltip({
  #   placement: 'bottom',
  #   delay: { show: 500, hide: 0 }
  # })
  # $('.likes_small > a').tooltip({
  #   delay: { show: 500, hide: 0 }
  # })
  
  # Click a Like to submit to server
  $(document).on 'click', '.like_toggle', ->
    $this = $(this)
    if $(this).parents('#player_likes_container').length > 0
      className = 'spinner_likes_title'
    else
      if $(this).parent().hasClass('likes_small')
        className = 'spinner_likes_small'
      else if $(this).parent().hasClass('likes_large')
        className = 'spinner_likes_large'
    spinner = App.Util.newSpinner className
    $(this).parent().append spinner.el
    $.ajax({
      type: 'post',
      url: '/toggle-like',
      data: { 'likable_type': $this.data('type'), 'likable_id': $this.data('id') }
      dataType: 'json',
      success: (r) ->
        spinner.stop()
        if r.success
          App.Util.feedback({ notice: r.msg })
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
  
  ###############################################

  # Rollover item list to reveal context button and drag arrows (if present)
  .on 'mouseover', '.item_list > li', ->
    $(this).find('.btn_context').css 'visibility', 'visible'
    $(this).find('.drag_arrows_vertical').css 'visibility', 'visible'
  .on 'mouseout', '.item_list > li', ->
    $(this).find('.btn_context').css 'visibility', 'hidden'
    $(this).find('.drag_arrows_vertical').css 'visibility', 'hidden'
  
  # Follow h2>a links in .item_list.clickable > li
  .on 'click', '.item_list > li', (e) ->
    if $(this).parent('ul').hasClass 'clickable'
      unless e.target.target and e.target.target is '_blank'
        $link = $(this).children('h2').find 'a'
        if $link.hasClass('non-remote')
          location.href = $link.attr('href')
        else
          App.Util.followLink $link
  
  # Share links bring up a modal to display a url
  .on 'click', '.share', ->
    $('#share_url').html("<p>"+$('body').data('base-url')+$(this).data('url')+"</p>")
    if $(this).hasClass('share_track')
      $('#share_track_tips').show()
    else
      $('#share_track_tips').hide()
    $('#share_modal').modal('show')
    