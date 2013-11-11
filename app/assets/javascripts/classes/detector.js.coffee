class @Detector
  
  constructor: ->
    @detectPlatform()
  
  detectPlatform: ->
    # Mac/Firefox not supported
    if /Firefox[\/\s](\d+\.\d+)/.test(navigator.userAgent) and /Mac/.test(navigator.userAgent)
      @unsupportedBrowser()
    # IE not supported
    else if eval "/*@cc_on!@*/!1" # only IE can execute this
      @unsupportedBrowser()
    # Suggest PhishOD on iOS
    else if /(iPhone|iPad|iPod)/g.test(navigator.userAgent)
      @iOS()
      
    # MOBILE NOT SUPPORTED
    # window.location.href = '/mobile-unsupported' if /Android|webOS|iPhone|iPad|iPod|BlackBerry/i.test(navigator.userAgent)

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
        
        urlParts = window.location.pathname[1...].split '/'
        time     = window.location.search[3...-1].split 'm'
        phishUrl = '/'

        if urlParts[0] is ''
          urlParts = []

        if time[0] is ''
          time = []

        if urlParts.length >= 1
          phishUrl += urlParts[0]

        if urlParts.length >= 2
          phishUrl += '/' + $('.playable_track').first().data('id')

          if time.length > 0
            phishUrl += '/' + time.join('/')

        window.location = 'phishod://' + phishUrl;
        $.cookie('appInstalled', 'true', { expires: 365 * 10 })
      else
        $.cookie('appInstalled', 'false', { expires: 365 * 10 })
  
  unsupportedBrowser: ->
    window.location.href = '/browser-unsupported'