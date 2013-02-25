# This is a manifest file that'll be compiled into application.js, which will include all the files
# listed below.
#
# Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
# or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
#
# It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
# the compiled file.
#
# WARNING: THE FIRST BLANK LINE MARKS THE END OF WHAT'S TO BE PROCESSED, ANY BLANK LINE SHOULD
# GO AFTER THE REQUIRES BELOW.

//= require jquery
//= require jquery_ujs
//= require twitter/bootstrap
//= require history
//= require_tree .

page_init = true
followLink = ($el) ->
  page_init = false
  # console.log $el
  History.pushState {href: $el.attr 'href'}, 'phish.in', $el.attr 'href'
  window.scrollTo 0, 0

$ ->
  
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
    followLink $(this) if $(this).attr('href') != "#" and $(this).attr('href') != 'null'
    false
  ###############################################
  
  # Hide page-loaded feedback after a timeout
  setTimeout( ->
    $('#feedback').hide('slide')
  , 3000)
  
  ###############################################
  
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
    followLink $(this).find 'a'
  
  # Follow h1>a links in .item_list.clickable > li
  $(document).on 'click', '.item_list > li', ->
    if $(this).parent('ul').hasClass 'clickable'
      followLink $(this).children('h2').find 'a'
  
  # Share links bring up
  $(document).on 'click', '.share', ->
    $('#share_modal_body').html("<p>"+$('#app_data').data('base-url')+$(this).data('url')+"</p>")
    $('#share_modal').modal('show')
    