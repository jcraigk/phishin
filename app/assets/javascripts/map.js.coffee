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
    @green_icon       = 'http://maps.google.com/mapfiles/ms/icons/green-dot.png'
    this.initMap()
  
  initMap: ->
    if container = $("#google_map").get 0
      @map = new @google.maps.Map(container, {
        center: new @google.maps.LatLng(@default_lat, @default_lng),
        zoom: 4,
        mapTypeId: @google.maps.MapTypeId.HYBRID
      })
  
  handleSearch: (term, distance) ->
    distance = parseFloat(distance)
    if term and distance > 0
      geocoder = new @google.maps.Geocoder()
      geocoder.geocode({ 'address': term}, (results, status) =>
        if status == @google.maps.GeocoderStatus.OK
          this._geocodeSuccess(results, distance)
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
    # this._createMarker(lat, lng, @green_icon)
    # Create circle for zoom level
    @view_circle.setMap null if @init == false
    @init = false
    @view_circle = new @google.maps.Circle({
      center: new @google.maps.LatLng(lat, lng),
      fillOpacity: 0,
      strokeOpacity:1,
      map: @map,
      radius: this._milesToMeters(distance)
    })
    @map.fitBounds @view_circle.getBounds()
    # Fetch venues from server
    $.ajax({
      url: "/search-map?lat=#{lat}&lng=#{lng}&distance=#{distance}&date_start=#{$('#map_date_start').val()}&date_stop=#{$('#map_date_stop').val()}",
      success: (r) =>
        if r.success
          this._drawVenueMarkers(r.venues)
        else
          @util.feedback { alert: 'No shows match your criteria'}
    })
    
  _drawVenueMarkers: (venues) ->
    for venue in venues
      html = "<h1><a href=\"/#{venue.slug}\">#{venue.name}</a></h1>"
      html += "<h2><i>Formerly #{venue.past_names}</i></h2>" if venue.past_names
      html += "<h2>#{venue.location}</h2>"
      word = 'show'
      if venue.shows_count != 1
        word += 's'
      html += "<h3>#{venue.shows_count} #{word}:</h3><ul>"
      for date in venue.show_dates
        html += "<li><a href=\"/#{date}\">#{date}</a></li>"
      html += "</ul>"
      this._createMarker(venue.latitude, venue.longitude, null, html)
  
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
      window.open(@map, marker)
    )
    @markers.push marker
    @windows.push window
  
  _clearAllMarkers: ->
    for marker in @markers
      marker.setMap null
    @markers = []
  
  _milesToMeters: (miles) ->
    miles * 1609.34
