import $ from 'jquery'
import 'jquery-ui/ui/widgets/slider'
import 'jquery-ui/ui/widgets/tooltip'
import 'jquery-ui/ui/widgets/dialog'

import Detector from './detector.js'
import Map from './map.js'
import Player from './player.js'
import Playlist from './playlist.js'
import Util from './util.js'

App = {}
export default App

$ ->

  ###############################################
  # Init
  ###############################################

  App.Detector     = null       # delay Detector creation until body load (Relisten track ID detection)
  App.Util         = new Util
  App.Player       = new Player
  App.Playlist     = new Playlist
  App.Map          = new Map

  App.Player.onReady()

  ###############################################
  # Assignments
  ###############################################

  $notice         = $ '.feedback_notice'
  $alert          = $ '.feedback_alert'
  $ajax_loading   = $ '#ajax_loading'
  $page           = $ '#page'

  ###############################################
  # Helpers
  ###############################################

  handleNavigation = ->
    state = window.history.state
    if state?.href
      $ajax_loading.css 'visibility', 'visible'
      $page.html ''

      fetch(state.href, {
        headers: {
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      .then (response) ->
        if response.ok
          response.text()
        else
          throw new Error('Network response was not ok')

      .then (html) ->
        $page.html html
        $ajax_loading.css 'visibility', 'hidden'
        App.Player._highlightActiveTrack()
        App.Player._updatePlaylistMode()

        # Scroll to proper position
        window.scrollTo(0, App.Util.historyScrollStates[state.id]) if App.Util.historyScrollStates[state.id]

        # Tooltips
        $('a[title]').each -> $(this).tooltip()
        $('.tag_label[title]').each -> $(this).tooltip()

        # Map
        if state.href.substr(0,4) is '/map'
          App.Map.initMap()
          term = $('#map_search_term').val()
          distance = $('#map_search_distance').val()
          App.Map.handleSearch(term, distance) if term and distance

        # Playlist
        else if state.href.substr(0,9) is '/playlist' or state.href.substr(0,6) is '/play/'
          App.Playlist.initPlaylist()

      .catch (error) ->
        console.log('Navigation fetch error: ', error.message)

  ###############################################
  # Prepare history.js
  ###############################################

  # User clicks back button
  window.addEventListener 'popstate', (e) -> handleNavigation()

  # Result of user clicking a link
  window.addEventListener 'navigation', (e) -> handleNavigation()

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
  # DOM interactions
  ###############################################

  # Initialize all dialogs (jQUery UI)
  $('.dialog').dialog({
    autoOpen: false,
    height: 400,
    width: 350,
    modal: true,
    draggable: false
  })

  # Click Phish On Demand app callout
  $(document).on 'click', '#relisten_callout', ->
    window.location = 'https://itunes.apple.com/us/app/relisten-all-live-music/id715886886'

  # Click Never Ending Splendor app callout
  $(document).on 'click', '#splendor_callout', ->
    window.location = 'https://play.google.com/store/apps/details?id=never.ending.splendor'

  # Prevent context menu clicks from playing parent track
  .on 'click', 'button', (e) ->
    e.stopPropagation()

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
  .on 'blur', '#playlist_name_input', (e) ->
    $('#playlist_slug_input').val App.Util.stringToSlug($(this).val())
  .on 'click', '#save_playlist_btn', (e) ->
    App.Playlist.handleSaveDialog()
  .on 'click', '#duplicate_playlist_btn', (e) ->
    App.Playlist.handleDuplicateDialog()
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
    App.Playlist.removeTrackFromPlaylist $(this).data('id')
    $(this).parents('li').remove()

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
    animate: false,
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

  # Toggle mute
  .on 'click', '#volume_icon', (e) ->
    App.Player.toggleMute()
    e.stopPropagation()

  ###############################################

  # Click to download an individual track
  # Set an iFrame's src to not interrupt playback
  $(document).on 'click', 'a.download', ->
    $('#download_iframe').attr('src', $(this).data('url'))

  ###############################################

  # Hover on player title to reveal Like toggle
  $(document).on 'mouseover', '#player_title_container', (e) ->
    if App.Player.active_track_id
      $('#player_title').css 'display', 'none'
      $('#player_likes_container').css 'display', 'inline-block'
  .on 'mouseout', '#player_title_container', (e) ->
    if App.Player.active_track_id
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
    $.ajax({
      type: 'post',
      url: '/toggle-like',
      data: { 'likable_type': $this.data('type'), 'likable_id': $this.data('id') }
      dataType: 'json',
      success: (r) ->
        if r.success
          App.Util.feedback({ notice: r.msg })
          if r.liked then $this.addClass('liked') else $this.removeClass('liked')
          $this.siblings('span').html r.likes_count
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

  .on 'click', '.share_with_timestamp', ->
    time = App.Util.readableDuration App.Player.currentPosition()
    App.Util.copyToClipboard($('body').data('base-url')+$(this).data('url')+'?t='+time)

  # Play random song track
  .on 'click', '#random_song_track_btn', (e) ->
    App.Player.playRandomSongTrack $(this).data('song-id')

  # Taper Notes link opens a dialog
  .on 'click', '.show_taper_notes', ->
    $('#taper_notes_content').html $(this).data('taper-notes')
    $('#taper_notes_dialog').dialog('open')

  # View Lyrics button opens a dialog
  .on 'click', '.song_lyrics', ->
    $('#lyrics_dialog').dialog('option', 'title', $(this).data('title'))
    $('#lyrics_content').html $(this).data('lyrics')
    $('#lyrics_dialog').dialog('open')

  # Tag instance click opens a dialog
  .on 'click', '.tag_label:not(.no-dialog)', ->
    $('#tag_dialog').dialog('option', 'title', $(this).data('title'))
    $('#tag_detail').html $(this).data('detail')
    $('#tag_dialog').dialog('open')

  # Keyboard shortcuts
  $(window).keydown (e) ->
    target = e.target.tagName.toLowerCase()
    return if target == 'input' || target == 'textarea'
    switch e.keyCode
      when 32 # Spacebar
        App.Player.togglePause()
        e.preventDefault()
      when 37 # <-
        if e.shiftKey
          App.Player.scrubBackward()
        else
          App.Player.previousTrack()
        e.preventDefault()
      when 39 # ->
        if e.shiftKey
          App.Player.scrubForward()
        else
          App.Player.nextTrack()
        e.preventDefault()
