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

init = true
followLink = ($el) ->
  init = false
  console.log $el
  History.pushState {href: $el.attr 'href'}, 'phish.in', $el.attr 'href'
  window.scrollTo 0, 0

$ ->
  
  # Prepare history.js
  History = window.History
  return false if !History.enabled
  History.Adapter.bind window, 'statechange', ->
    State = History.getState()
    History.log State.data, State.title, State.url
  History.Adapter.bind window, 'popstate', ->   
    state = window.History.getState()
    console.log state
    if state.data.href != undefined and !init
      $('#ajax_overlay').css 'visibility', 'visible'
      $.ajax
        url: state.data.href,
        success: (response) ->
          $('#page').html response
          $('#ajax_overlay').css 'visibility', 'hidden'
  
  # Display number of shows when rolling over a year
  $('.year_list li').hover(
    -> $(this).find('h2').css 'visibility', 'visible'
    -> $(this).find('h2').css 'visibility', 'hidden'
  )

  # Handle clicking links
  $('body').on 'click', 'a', ->
    if $(this).attr('href') != "#" and $(this).attr('href') != 'null'
      followLink $(this)
      false
  
  # Show context buttons on item list rollovers
  $('.item_list li').hover(
    -> $(this).find('.btn_context').css 'visibility', 'visible'
    -> $(this).find('.btn_context').css 'visibility', 'hidden'
  )
  
  # Show context button on header rollover
  $('#header').hover(
    -> $(this).find('.btn_context').css 'visibility', 'visible'
    -> $(this).find('.btn_context').css 'visibility', 'hidden'
  )
  
  # Clicking a year button goes to that year
  $('.year_list > li').on 'click', ->
    $('#page').hide
    $('#ajax_overlay').css 'visibility', 'visible'
    followLink $(this).find 'a'