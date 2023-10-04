class Util

  historyScrollStates: [] # Need to store scroll states outside history.js based on the way that library works

  constructor: ->
    @page_init          = true
    @page_init          = true
    @$feedback          = $ '#feedback'

  @feedback: (feedback) ->
    if feedback.alert
      msg = feedback.alert
      css = 'feedback_alert'
      icon = 'icon-exclamation-sign'
    else
      msg = feedback.notice
      css = 'feedback_notice'
      icon = 'icon-ok-sign'
    id = this._uniqueID()
    @$feedback.append "<p class=\"#{css}\" id=\"#{id}\"><i class=\"#{icon}\"></i> #{msg}</p>"
    setTimeout( ->
      $("##{id}").hide 'slide'
    , 3000)

  followLink: ($el) ->
    this.navigateTo $el.attr('href')

  navigateTo: (href) ->
    console.log("navigateTo: #{href}")
    @page_init = false

    # Save the current scroll position to the state
    scrollPosition = window.scrollY || document.documentElement.scrollTop || document.body.scrollTop || 0
    history.replaceState { href: window.location.href, scroll: scrollPosition }, document.title, window.location.href

    # Push the new state
    title = document.title
    history.pushState { href: href, scroll: 0 }, $('body').data('app-name'), href
    document.title = title

    console.log("navigateTo: #{href} (done)")

    # Manually trigger a popstate event
    window.dispatchEvent(new CustomEvent('navigation'))

  navigateToRefreshMap: ->
    url = "/map?map_term=#{$('#map_search_term').val().replace /\s/g, '+' }"
    url += "&distance=#{$('#map_search_distance').val()}"
    url += "&date_start=#{$('#map_date_start').val()}"
    url += "&date_stop=#{$('#map_date_stop').val()}"
    this.navigateTo url

  @readableDuration: (ms, style='colons', include_seconds=false) ->
    x = Math.floor(ms / 1000)
    seconds = x % 60
    seconds_with_zero = "#{if seconds < 10 then '0' else '' }#{seconds}"
    x = Math.floor(x / 60)
    minutes = x % 60
    minutes_with_zero = "#{if minutes < 10 then '0' else '' }#{minutes}"
    x = Math.floor(x / 60)
    hours = x % 24
    hours_with_zero = "#{if hours < 10 then '0' else '' }#{hours}"
    x = Math.floor(x / 24)
    days = x
    if style is 'letters'
      if days > 0
        "#{days}d #{hours}h #{minutes}m #{seconds}s"
      else if hours > 0
        if include_seconds
          "#{hours}h #{minutes}m #{seconds}s"
        else
          "#{hours}h #{minutes}m"
      else
        "#{minutes}m #{seconds}s"
    else
      if days > 0
        "#{days}::#{hours}:#{minutes_with_zero}:#{seconds_with_zero}"
      else if hours > 0
        "#{hours}:#{minutes_with_zero}:#{seconds_with_zero}"
      else
        "#{minutes}:#{seconds_with_zero}"

  @timeToMS: (time) ->
    time = "#{time}"
    if time.match /^\d+$/  # It's already in ms
      time
    else
      if matches = time.match /^(\d+)m$/
        (parseInt matches[1]) * 60 * 1000
      else if matches = time.match /^(\d+)s$/
        (parseInt matches[1]) * 1000
      else if matches = time.match /^(\d+)m(\d+)s$/
        (((parseInt matches[1]) * 60) + (parseInt matches[2])) * 1000
      else if matches = time.match /^(\d+):(\d+)$/
        (((parseInt matches[1]) * 60) + (parseInt matches[2])) * 1000
      else
        this.feedback { alert: "Invalid start time provided (#{time})" }
        0

  @stringToSlug: (str) ->
    str.toLowerCase().trim().replace(/[^a-z0-9\-\s]/g, '').replace(/[\s]/g, '-')

  @truncate: (string, length=40) ->
    if string.length > length then string.substring(0, length) + '...' else string

  showHTMLError: (str) ->
    $('body').append "<div id=\"system_error\">#{str.replace(/(\r\n|\n|\r)/gm,"<br />")}</div>"

  copyToClipboard: (text) ->
    el = $('#clipboard')
    el.val(text)
    el.select()
    document.execCommand('copy')
    App.Util.feedback({ notice: 'Link copied to clipboard' })

  _findMatch: (href) ->
    match = /^([^\?]+)\??(.+)?$/.exec(href.split("/")[1])
    match[1] if match

  _uniqueID: (length=8) ->
    id = ""
    id += Math.random().toString(36).substr 2 while id.length < length
    id.substr 0, length

export default Util
