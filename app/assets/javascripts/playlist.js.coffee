class @Playlist

  constructor: ->
    @Util                   = App.Util
    @$playlist_btn          = $ '#playlist_button .btn'
    @$save_playlist_modal   = $ '#save_playlist_modal'
  
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
        @Util.feedback { notice: success_msg }
        $('#current_playlist_tracks_label').html "#{track_ids.length} Tracks"
        $('#current_playlist_duration_label').html "<i class=\"icon-time icon-white\"></i>  #{@Util.readableDuration(duration, 'letters')}"
    })
  
  resetPlaylist: (track_id) ->
    $.ajax({
      type: 'post'
      url: '/reset-playlist',
      data: { 'track_id': track_id }
    })
    @$playlist_btn.addClass 'playing'
  
  clearPlaylist: ->
    $.ajax({
     url: '/clear-playlist',
     type: 'post',
     success: (r) =>
       @$playlist_btn.removeClass 'playing'
       $('#current_playlist').html ''
       $('#empty_playlist_msg').show()
       @Util.feedback { notice: 'Playlist is now empty' }
    })
  
  savePlaylist: (name, slug) ->
    @$save_playlist_modal.modal('hide')
    $.ajax({
     url: '/save-playlist',
     type: 'post',
     data: { name: name, slug: slug }
     success: (r) =>
       if r.success
         #todo: update details (name, slug, etc) of playlist
         @Util.feedback { notice: 'Playlist saved'}
       else
         @Util.feedback { alert: r.msg }
    })
    