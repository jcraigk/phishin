class @Map

  constructor: ->
    @init             = true
    @markers          = []
    @windows          = []
    @map              = {}
    @view_circle      = {}
    @util             = App.Util
    @google           = google
    @default_lat      = 39.126864
    @default_lng      = -94.627411
    @green_icon       = 'https://maps.google.com/mapfiles/ms/icons/green-dot.png'

  initMap: ->
    if container = $("#google_map").get 0
      @map = new @google.maps.Map(container, {
        center: new @google.maps.LatLng(@default_lat, @default_lng),
        zoom: 4,
        mapTypeId: @google.maps.MapTypeId.HYBRID
      })

  handleSearch: (term, distance) ->
    distance = parseFloat distance
    if term and distance > 0
      geocoder = new @google.maps.Geocoder()
      geocoder.geocode({ 'address': term}, (results, status) =>
        if status is @google.maps.GeocoderStatus.OK
          this._geocodeSuccess results, distance
        else
          # util.feedback { alert: "Geocode was not successful because: #{status}" }
          @util.feedback { alert: "Google Maps returned no results" }
      )
    else
      @util.feedback { alert: 'Provide a term and a distance'}

  _geocodeSuccess: (results, distance) ->
    this._clearAllMarkers()
    this._setCenter results[0].geometry.location
    lat = results[0].geometry.location.lat()
    lng = results[0].geometry.location.lng()
    @view_circle.setMap null if @init is false
    @init = false
    @view_circle = new @google.maps.Circle({
      center: new @google.maps.LatLng(lat, lng),
      fillOpacity: 0,
      strokeOpacity:1,
      map: @map,
      radius: this._milesToMeters distance
    })
    # Fetch venues from server
    $.ajax({
      url: "/search-map?lat=#{lat}&lng=#{lng}&distance=#{distance}&date_start=#{$('#map_date_start').val()}&date_stop=#{$('#map_date_stop').val()}",
      success: (r) =>
        if r.success
          this._drawVenueMarkers r.venues
          if r.venues[1]
            bounds = new google.maps.LatLngBounds()
            for venue in r.venues
              bounds.extend(new google.maps.LatLng(venue.latitude, venue.longitude))
            @map.fitBounds bounds
          else
            @map.fitBounds @view_circle.getBounds()
        else
          @util.feedback { alert: 'No shows match your criteria'}
    })

  _drawVenueMarkers: (venues) ->
    for venue in venues
      html = "<h1><a href=\"/#{venue.slug}\">#{venue.name}</a></h1>"
      html += "<h2><i>Also known as #{venue.other_names.join(', ')}</i></h2>" if venue.other_names
      html += "<h2>#{venue.location}</h2>"
      word = 'show'
      if venue.shows_count != 1
        word += 's'
      html += "<h3>#{venue.shows_count} #{word}:</h3><ul>"
      for show in venue.shows
        html += "<li><a href=\"/#{show.date}\">#{show.date}</a></li>"
      html += "</ul>"
      this._createMarker venue.latitude, venue.longitude, null, html

  _setCenter: (location) ->
    @map.setCenter location

  _createMarker: (lat, lng, icon=null, infoWindowContent) ->
    windows = @windows
    marker = new @google.maps.Marker({
      position: new @google.maps.LatLng(lat, lng),
      map: @map,
      icon: icon
    })
    window = new @google.maps.InfoWindow({
      content: infoWindowContent,
      maxWidth: 600
    })
    @google.maps.event.addListener(marker, 'click', ->
      for win in windows
        win.close()
      window.open @map, marker
    )
    @markers.push marker
    @windows.push window

  _clearAllMarkers: ->
    for marker in @markers
      marker.setMap null
    @markers = []

  _milesToMeters: (miles) ->
    miles * 1609.34
