import $ from 'jquery'
import 'jquery-ui/ui/widgets/sortable'
import 'jquery-ui/ui/widgets/dialog'

import Util from './util.js'
import Player from './player.js'

class Playlist

  constructor: ->
    @Util                   = new Util
    @Player                 = new Player
    @$save_dialog           = $ '#save_playlist_dialog'
    @$save_action_dropdown  = $ '#save_action_dropdown'
    @$save_action_new       = $ '#save_action_new'
    @$save_action_existing  = $ '#save_action_existing'
    @$playlist_name_input   = $ '#playlist_name_input'
    @$playlist_slug_input   = $ '#playlist_slug_input'

  initPlaylist: ->
    this._getPlaylist()
    $('#active_playlist').sortable({
      placeholder: "ui-state-highlight",
      update: =>
        this.updatePlaylist('Track repositioned in playlist')
    })

  updatePlaylist: (success_msg) ->
    track_ids = []
    duration = 0
    $('#active_playlist > li').each( (idx, el) ->
      track_ids.push $(this).data('id')
      duration += parseInt $(this).data('track-duration')
      $(this).find('.position_num').html "#{idx+1}"
    )
    $.ajax({
      url: '/reposition-playlist'
      type: 'POST'
      data: { 'track_ids': track_ids }
      success: (r) =>
        this._updatePlaylistStats(track_ids.length, duration / 1000)
        @Util.feedback { notice: success_msg }
    })

  addTrackToPlaylist: (track_id) ->
    $.ajax({
      type: 'POST'
      url: '/add-track'
      data: { 'track_id': track_id}
      success: (r) =>
        if r.success
          this.initPlaylist()
          @Util.feedback { notice: 'Track added to playlist' }
        else
          @Util.feedback { alert: r.msg }
    })

  removeTrackFromPlaylist: (track_id) ->
    $.ajax({
      type: 'POST',
      url: '/remove-track',
      data: { 'track_id': track_id}
      success: (r) =>
        if r.success
          @Util.feedback { notice: 'Track removed from playlist' }
        else
          @Util.feedback { alert: r.msg }
    })

  addShowToPlaylist: (show_id) ->
    $.ajax({
      type: 'POST',
      url: '/add-show',
      data: { 'show_id': show_id}
      success: (r) =>
        if r.success
          this.initPlaylist()
          @Util.feedback { notice: r.msg }
        else
          @Util.feedback { alert: r.msg }
    })

  clearPlaylist: (supress_feedback=true)->
    $.ajax({
     url: '/clear-playlist'
     type: 'POST'
     success: (r) =>
       @Player.stopAndUnload()
       $('#playlist_data').attr 'data-id', 0
       $('#playlist_data').attr 'data-name', ''
       $('#playlist_data').attr 'data-slug', ''
       $('#playlist_data').attr 'data-user-id', ''
       $('#playlist_data').attr 'data-username', ''
       $('#delete_playlist_btn').hide()
       $('#bookmark_playlist_btn').hide()
       $('#clear_playlist_btn').hide()
       $('#save_playlist_btn').hide()
       $('#active_playlist').html ''
       $('#playlist_title').html '(Untitled Playlist)'
       $('#playlist_author').hide()
       this._updatePlaylistStats()
       $('#empty_playlist_msg').show()
       unless supress_feedback then @Util.feedback { notice: 'Actve playlist is now empty' }
    })

  bookmarkPlaylist: ->
    $.ajax({
      type: 'POST'
      url: '/bookmark-playlist'
      data: { 'id': $('#playlist_data').attr 'data-id' }
      success: (r) =>
        if r.success
          @Util.feedback { notice: 'Playlist bookmarked' }
        else
          @Util.feedback { alert: r.msg }
    })

  unbookmarkPlaylist: ->
    $.ajax({
      type: 'POST'
      url: '/unbookmark-playlist'
      data: { 'id': $('#playlist_data').attr 'data-id' }
      success: (r) =>
        if r.success
          @Util.feedback { notice: 'Playlist unbookmarked' }
        else
          @Util.feedback { alert: r.msg }
    })

  handleSaveDialog: ->
    if name = $('#playlist_data').attr 'data-name'
      @$save_action_existing.attr 'disabled', false
      @$save_action_existing.attr 'selected', true
      @$playlist_name_input.val name
      @$playlist_slug_input.val $('#playlist_data').attr 'data-slug'
    else
      @$save_action_existing.attr 'disabled', true
      @$playlist_name_input.val ''
      @$playlist_slug_input.val ''
    @$save_dialog.dialog 'open'

  handleDuplicateDialog: ->
    @$save_action_existing.attr 'disabled', true
    @$playlist_name_input.val ''
    @$playlist_slug_input.val ''
    @$save_dialog.dialog 'open'

  savePlaylist: ->
    @$save_dialog.dialog 'close'
    $('#duplicate_playlist_btn').hide()
    $('#unbookmark_playlist_btn').hide()
    $('#bookmark_playlist_btn').hide()
    $.ajax
      url: '/save-playlist'
      type: 'POST'
      data: {
        id: $('#playlist_data').attr('data-id')
        name: @$playlist_name_input.val()
        slug: @$playlist_slug_input.val()
        save_action: @$save_action_dropdown.val()
      }
      success: (r) =>
        if r.success
          $('#playlist_data').attr 'data-id', r.id
          $('#playlist_data').attr 'data-name', r.name
          $('#playlist_data').attr 'data-slug', r.slug
          $('#playlist_title').html r.name
          $('#delete_playlist_btn').show()
          $('#bookmark_playlist_btn').show()
          $('#clear_playlist_btn').show()
          $('#save_playlist_btn').show()
          @Util.feedback { notice: r.msg }
        else
          @Util.feedback { alert: r.msg }

  deletePlaylist: (id) ->
    $.ajax({
     url: '/delete-playlist'
     type: 'POST'
     data: {
       id: $('#playlist_data').attr('data-id'),
     }
     success: (r) =>
       if r.success
         this.clearPlaylist()
         @Util.feedback { notice: r.msg }
       else
         @Util.feedback { alert: r.msg }
    })

  _getPlaylist: ->
    $.ajax({
      url: '/load-playlist'
      success: (r) =>
        if r.playlist && r.playlist.length > 0
          $('#empty_playlist_msg').hide()
        else
          $('#empty_playlist_msg').show()
    })

  _updatePlaylistStats: (num_tracks=0, duration=0) ->
    $('#active_playlist_tracks_label').html "Tracks: #{num_tracks}"
    $('#active_playlist_duration_label').html "Length: #{@Util.readableDuration(duration, 'letters')}"

export default Playlist
