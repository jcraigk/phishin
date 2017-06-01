class @Detector

  constructor: ->
    @detectPlatform()

  detectPlatform: ->
    if eval "/*@cc_on!@*/!1" # only IE can execute this
      @unsupportedBrowser()
    # Suggest PhishOD on iOS
    else if /(iPhone|iPad|iPod)/g.test(navigator.userAgent)
      @iOS()

  iOS: ->
    unless $.cookie('appInstalled') and $.cookie('appInstalled') is 'false'
      if $.cookie('appInstalled') is 'true'
        msg = 'Recommended: do you want to enjoy this content using the Phish On Demand app?'
      else
        msg = 'Phish On Demand is an app that lets you enjoy Phish.in content on your iOS device. Install it?'
      if confirm msg
        loadedAt = +new Date
        setTimeout( ->
          alert 'Something went wrong' if +new Date - loadedAt < 2000
        , 1000);

        # Convert web path to PhishOD path
        urlParts = window.location.pathname[1...].split '/'
        time     = window.location.search[3...-1].split 'm'
        path = '/'
        urlParts = [] if urlParts[0] is ''
        time = [] if time[0] is ''
        path += urlParts[0] if urlParts.length >= 1
        if urlParts.length >= 2
          path += '/' + $('.playable_track').first().attr('data-id')
          path += '/' + time.join('/') if time.length > 0
        # alert('phishod://' + path)
        window.location = 'phishod://' + path;

        $.cookie('appInstalled', 'true', { expires: 365 * 10 })
      else
        $.cookie('appInstalled', 'false', { expires: 365 * 10 })

  unsupportedBrowser: ->
    window.location.href = '/browser-unsupported'