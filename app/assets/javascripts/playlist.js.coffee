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
    console.log @$save_action_dropdwon
  
  initPlaylist: ->
    $.ajax({
      url: '/get-playlist',
      success: (r) =>
        if r.playlist.length > 0
          @$playlist_btn.addClass 'playing'
          $('#empty_playlist_msg').hide()
        else
          @$playlist_btn.removeClass 'playing'
          $('#empty_playlist_msg').show()
    })
    # Sortable playlist AJAX load
    $('#current_playlist').sortable({
      placeholder: "ui-state-highlight",
      update: =>
        this.updatePlaylist 'Track moved in playlist'
    })
    this._refreshPlaylistDropdown()
    
  updatePlaylist: (success_msg) ->
    track_ids = []
    duration = 0
    $('#current_playlist > li').each( (idx, el) ->
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
  
  _updatePlaylistStats: (num_tracks=0, duration=0) ->
    $('#current_playlist_tracks_label').html "#{num_tracks} Tracks"
    $('#current_playlist_duration_label').html "<i class=\"icon-time icon-white\"></i>  #{@Util.readableDuration(duration, 'letters')}"
  
  clearPlaylist: ->
    $.ajax({
     url: '/clear-playlist',
     type: 'post',
     success: (r) =>
       @Player.stopAndUnload()
       @$playlist_btn.removeClass 'playing'
       $('#playlist_data').attr 'data-id', 0
       $('#playlist_data').attr 'data-name', ''
       $('#playlist_data').attr 'data-slug', ''
       $('#playlist_data').attr 'data-author', ''
       $('#current_playlist').html ''
       $('#playlist_title').html 'Current Playlist'
       this._updatePlaylistStats()
       $('#playlist_info').hide()
       $('#empty_playlist_msg').show()
       @Util.feedback { notice: 'Playlist is now empty' }
    })
  
  handleSavePlaylistModal: ->
    if name = $('#playlist_data').attr 'data-name'
      @$save_action_existing.attr 'disabled', false
      @$playlist_name_input.val name
      @$playlist_slug_input.val $('#playlist_data').attr 'data-slug'
    else
      @$save_action_existing.attr 'disabled', true
      @$playlist_name_input.val ''
      @$playlist_slug_input.val ''
    @$save_modal.modal 'show'
  
  savePlaylist: ->
    @$save_modal.modal 'hide'
    $.ajax({
     url: '/save-playlist',
     type: 'post',
     data: {
       id:      $('#playlist_data').attr('data-id'),
       name:    @$playlist_name_input.val(),
       slug:    @$playlist_slug_input.val(),
       action:  @$save_action_dropdown.val()
     }
     success: (r) =>
       if r.success
         #todo: update visual details (name, slug, etc) of playlist
         $('#playlist_data').attr 'data-id', r.id
         $('#playlist_data').attr 'data-name', r.name
         $('#playlist_data').attr 'data-slug', r.slug
         $('#playlist_data').show()
         this._refreshPlaylistDropdown()
         @Util.feedback { notice: 'Playlist saved'}
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
         this.clearPlaylist()
         this._refreshPlaylistDropdown()
         @Util.feedback { notice: 'Playlist deleted' }
       else
         @Util.feedback { alert: r.msg }
    })
  
  _refreshPlaylistDropdown: ->
    $list = $('#load_playlist_list')
    $list.empty()
    $.ajax({
     url: '/get-saved-playlists',
     success: (r) =>
       if r.success
         console.log r
         for p in JSON.parse(r.playlists)
           $list.append "<li><a href=\"/play/#{p.slug}\">#{p.name}</a></li>"
    })
    