//= require jquery
//= require jquery_ujs
//= require jquery-ui/slider
//= require jquery-ui/sortable
//= require jquery-ui/datepicker
//= require jquery.cookie
//= require twitter/bootstrap
//= require soundmanager2
//= require native.history
//= require classes/detector
//= require classes/util
//= require classes/player
//= require classes/playlist
//= require classes/map
//= require spin.min
//= require phishtracks-stats-0.0.3
//= require_tree .

# Generic namespace
@App = {}

$ ->

  ###############################################
  # Init
  ###############################################

  App.Detector     = null       # delay Detector creation until body load (Relisten track ID detection)
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
          App.Util.showHTMLError(response) if status is 'error'

          $ajax_overlay.css 'visibility', 'hidden'

          # Scroll to proper position (not currently working)
          window.scrollTo 0, App.Util.historyScrollStates[state.id] if App.Util.historyScrollStates[state.id]

          # Tooltips
          $('a[title]').tooltip()

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
    match = /^(http|https):\/\/(.+)$/.exec(window.location)
    href = match[2].substr(match[2].indexOf('/'), match[2].length - 1)
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
  soundManager.onready ->
    App.Player.onReady()

  ###############################################
  # DOM interactions
  ###############################################

  # Click Phish On Demand app callout
  $(document).on 'click', '#relisten_callout', ->
    window.location = 'https://itunes.apple.com/us/app/relisten-all-live-music/id715886886'

  # Click RoboPhish app callout
  $(document).on 'click', '#robophish_callout', ->
    window.location = 'https://play.google.com/store/apps/details?id=com.bayapps.android.robophish&hl=en'

  # Click a link to load page via ajax
  .on 'click', 'a', ->
    unless $(this).hasClass('non-remote')
      App.Util.followLink $(this) if $(this).attr('href') != "#" and $(this).attr('href') != 'null'
      false

  ###############################################

  # Submit new user
  .on 'submit', '#new_user', (e) ->
    $('#new_user_container').fadeTo('fast', 0.5)
    $('#new_user_submit_btn').val('Processing...')

  ###############################################

  # Click search box to focus on textbox
  .on 'click', '#search_box', (e) ->
    $('#search_term').focus()

  # Submit search
  .on 'keypress', '#search_term', (e) ->
    if e.which is 13
      App.Util.navigateTo '/search?term='+encodeURI($('#search_term').val())
      $(this).val ''
      $(this).blur()

  ###############################################
  # Map controls

  .on 'click', '#map_search_submit', (e) ->
    console.log 'dinky stink'
    App.Util.navigateToRefreshMap()
  .on 'keypress', '#map_search_term', (e) ->
    App.Util.navigateToRefreshMap() if e.which is 13
  .on 'keypress', '#map_search_distance', (e) ->
    App.Util.navigateToRefreshMap() if e.which is 13
  .on 'keypress', '#map_date_start', (e) ->
    App.Util.navigateToRefreshMap() if e.which is 13
  .on 'keypress', '#map_date_stop', (e) ->
    App.Util.navigateToRefreshMap() if e.which is 13

  # Submit map search
  term = $('#map_search_term').val()
  distance = $('#map_search_distance').val()
  App.Map.handleSearch(term, distance) if term and distance

  ###############################################

  # Playlist stuff
  $(document)
  .on 'click', '#playlist_mode_btn', (e) ->
    App.Player.togglePlaylistMode()
  .on 'click', '#playlist_button', ->
    App.Util.navigateTo $(this).data('url')
  .on 'click', '#share_playlist_btn', ->
    App.Util.copyToClipboard("#{$('body').data('base-url')}/play/#{$('#playlist_data').attr('data-slug')}")
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
  .on 'change', '.playback_loop', (e) ->
    App.Playlist.handlePlaybackLoopChange()
  .on 'change', '.playback_shuffle', (e) ->
    App.Playlist.handlePlaybackShuffleChange()

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

  # Click a track title to play it (for iOS devices requiring a link)
  .on 'click', '.track_title a', (e) ->
    clicked_from_playlist = $(this).parents('#active_playlist').length > 0
    id = $(this).parents('.playable_track').data('id')
    if App.Player.playlist_mode and !clicked_from_playlist
      App.Playlist.addTrackToPlaylist id
    else
      App.Player.playTrack id
      unless clicked_from_playlist
        App.Player.setCurrentPlaylist id

  # Click Play in a context menu to play the track
  .on 'click', '.context_play_track', (e) ->
    clicked_from_playlist = $(this).parents('#active_playlist').length > 0
    if App.Player.playlist_mode and !clicked_from_playlist
      App.Playlist.addTrackToPlaylist $(this).data('id')
    else
      App.Player.playTrack $(this).data('id')
      unless clicked_from_playlist
        App.Player.setCurrentPlaylist $(this).data('id')

  # Click the Play/Pause button
  .on 'click', '#control_playpause', (e) ->
    App.Player.togglePause()

  # Click the Previous button
  .on 'click', '#control_previous', (e) ->
    App.Player.previousTrack()

  # Click the Next button
  .on 'click', '#control_next', (e) ->
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

  # Loop / Shuffle controls
  $(document).on 'click', '#loop_checkbox', (e) ->
    $(this).attr('checked', !$(this).attr('checked'))
    e.stopPropagation()
  .on 'click', '#shuffle_checkbox', (e) ->
    $(this).attr('checked', !$(this).attr('checked'))
    e.stopPropagation()

  # Toggle mute
  .on 'click', '#volume_icon', (e) ->
    App.Player.toggleMute()
    e.stopPropagation()

  # Play button tooltip
  $('#playpause_tooltip').tooltip({trigger: 'manual'}).tooltip('show')

  ###############################################

  # Click to download an individual track
  # Set an iFrame's src to not interrupt playback
  $(document).on 'click', 'a.download', ->
    $('#download_iframe').attr('src', $(this).data('url'))

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
  $('.likes_large a').tooltip
    placement: 'bottom',
    delay:
      show: 500
      hide: 0
  $('.likes_small > a').tooltip
    delay:
      show: 500
      hide: 0

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
          console.log(r.likes_count)
          # Update other instances of this track's Like controls
          $('.like_toggle[data-type="track"]').each(->
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

  # Share links copy the share link to clipboard
  .on 'click', '.share', ->
    App.Util.copyToClipboard($('body').data('base-url')+$(this).data('url'))

  # Play random song track
  .on 'click', '#random_song_track_btn', (e) ->
    App.Player.playRandomSongTrack $(this).data('song-id')

  # Taper Notes link opens a modal
  .on 'click', '.show_taper_notes', ->
    $('#taper_notes_content').html($(this).data('taper-notes'))
    $('#taper_notes_date').html $(this).data('show-date')
    $('#taper_notes_modal').modal('show')

  # Keyboard shortcuts
  $(window).keydown (e) ->
    target = e.target.tagName.toLowerCase()
    return if target == 'input' || target == 'textarea'
    switch e.keyCode
      when 32 # Spacebar
        App.Player.togglePause()
        e.preventDefault()
      when 37 # <-
        App.Player.previousTrack()
        e.preventDefault()
      when 39 # ->
        App.Player.nextTrack()
        e.preventDefault()
