class @Playlist

  constructor: ->
    @Util                   = App.Util
    @Player                 = App.Player
    @$playlist_btn          = $ '#playlist_button .btn'
    @$save_modal            = $ '#save_playlist_modal'
    @$save_action_dropdown  = $ '#save_action_dropdown'
    @$save_action_new       = $ '#save_action_new'
    @$save_action_existing  = $ '#save_action_existing'
    @$playlist_name_input   = $ '#playlist_name_input'
    @$playlist_slug_input   = $ '#playlist_slug_input'
    this._getPlaylist()
  
  initPlaylist: ->
    this._getPlaylist()
    $('#active_playlist').sortable({
      placeholder: "ui-state-highlight",
      update: =>
        this.updatePlaylist 'Track moved in playlist'
    })
    # this._refreshPlaylistDropdown()
    
  updatePlaylist: (success_msg) ->
    track_ids = []
    duration = 0
    $('#active_playlist > li').each( (idx, el) ->
      track_ids.push $(this).data('id')
      duration += parseInt $(this).data('track-duration')
      $(this).find('.position_num').html "#{idx+1}"
    )
    $.ajax({
      url: '/update-current-playlist',
      type: 'post',
      data: { 'track_ids': track_ids },
      success: (r) =>
        this._updatePlaylistStats(track_ids.length, duration)
        @Util.feedback { notice: success_msg }
    })
  
  addTrackToPlaylist: (track_id) ->
    $.ajax({
      type: 'post',
      url: '/add-track',
      data: { 'track_id': track_id}
      success: (r) =>
        if r.success
          this.initPlaylist()
          @Util.feedback { notice: 'Track added to playlist' }
        else
          @Util.feedback { alert: r.msg }
    })
  
  addShowToPlaylist: (show_id) ->
    $.ajax({
      type: 'post',
      url: '/add-show',
      data: { 'show_id': show_id}
      success: (r) =>
        if r.success
          this.initPlaylist()
          @Util.feedback { notice: r.msg }
        else
          @Util.feedback { alert: r.msg }
    })
  
  removeTrackFromPlaylist: (track_id) ->
    if $('#active_playlist').children('li').size() is 0
      this.clearPlaylist()
      @Player.stopAndUnload()
    else
      this.updatePlaylist 'Track removed from playlist'
      @Player.stopAndUnload()
  
  handleOptionChange: ->
    $.ajax({
      type: 'post',
      url: '/submit-playlist-options',
      data: {
        'loop': $('#loop_checkbox').prop('checked'),
        'randomize': $('#randomize_checkbox').prop('checked')
      }
      success: (r) =>
        if r.success
          @Util.feedback { notice: 'Playlist options saved' }
        else
          @Util.feedback { alert: r.msg }
    })

  clearPlaylist: (supress_feedback=true)->
    $.ajax({
     url: '/clear-playlist',
     type: 'post',
     success: (r) =>
       @Player.stopAndUnload()
       @$playlist_btn.removeClass 'playlist_active'
       $('#playlist_data').attr 'data-id', 0
       $('#playlist_data').attr 'data-name', ''
       $('#playlist_data').attr 'data-slug', ''
       $('#playlist_data').attr 'data-user-id', ''
       $('#playlist_data').attr 'data-user-name', ''
       $('#delete_playlist_btn').hide()
       $('#active_playlist').html ''
       $('#playlist_title').html '(Untitled Playlist)'
       this._updatePlaylistStats()
       $('#empty_playlist_msg').show()
       if provide_feedback then @Util.feedback { notice: 'Actve Playlist is now empty' }
    })

  bookmarkPlaylist: (playlist_id) ->
    $.ajax({
      type: 'post',
      url: '/bookmark-playlist',
      data: { 'playlist_id': playlist_id}
      success: (r) =>
        if r.success
          @Util.feedback { notice: 'Playlist bookmarked' }
        else
          @Util.feedback { alert: r.msg }
    })
  
  handleSaveModal: ->
    if name = $('#playlist_data').attr 'data-name'
      @$save_action_existing.attr 'disabled', false
      @$playlist_name_input.val name
      @$playlist_slug_input.val $('#playlist_data').attr 'data-slug'
    else
      @$save_action_existing.attr 'disabled', true
      @$playlist_name_input.val ''
      @$playlist_slug_input.val ''
    @$save_modal.modal 'show'
  
  handleShareModal: ->
    if $('#playlist_data').attr('data-id') is "0"
      url = "You must first save a playlist to share it."
    else
      url = "#{$('body').data('base-url')}/play/#{$('#playlist_data').attr('data-slug')}"
    $('#share_url').html("<p>#{url}</p>")
    $('#share_track_tips').hide()
    $('#share_modal').modal('show')
  
  savePlaylist: ->
    @$save_modal.modal 'hide'
    $.ajax({
     url: '/save-playlist',
     type: 'post',
     data: {
       id:      $('#playlist_data').attr('data-id')
       name:    @$playlist_name_input.val()
       slug:    @$playlist_slug_input.val()
       save_action:  @$save_action_dropdown.val()
     }
     success: (r) =>
       if r.success
         #todo: update visual details (name, slug, etc) of playlist
         $('#playlist_data').attr 'data-id', r.id
         $('#playlist_data').attr 'data-name', r.name
         $('#playlist_data').attr 'data-slug', r.slug
         $('#playlist_title').html r.name
         # this._refreshPlaylistDropdown()
         @Util.feedback { notice: r.msg }
       else
         @Util.feedback { alert: r.msg }
    })
  
  deletePlaylist: (id) ->
    $.ajax({
     url: '/delete-playlist',
     type: 'post',
     data: {
       id: $('#playlist_data').attr('data-id'),
     }
     success: (r) =>
       if r.success
         this.clearPlaylist false
         @Util.feedback { notice: r.msg }
       else
         @Util.feedback { alert: r.msg }
    })
  
  _getPlaylist: ->
    $.ajax({
      url: '/get-playlist',
      success: (r) =>
        if r.playlist.length > 0
          @$playlist_btn.addClass 'playlist_active'
          $('#empty_playlist_msg').hide()
        else
          @$playlist_btn.removeClass 'playlist_active'
          $('#empty_playlist_msg').show()
    })
  
  _updatePlaylistStats: (num_tracks=0, duration=0) ->
    $('#active_playlist_tracks_label').html "Tracks: #{num_tracks}"
    $('#active_playlist_duration_label').html "Length: #{@Util.readableDuration(duration, 'letters')}"
    