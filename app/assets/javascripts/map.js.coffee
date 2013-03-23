class @Map
  
  constructor: (util) ->
    @map              = {}
    @util             = util
    @google           = google
    
    # Initialize map
    this.init()
  
  init: ->
    if container = document.getElementById("google_map")
      @map = new @google.maps.Map(container, {
        center: new @google.maps.LatLng(44.476788,-73.211696),
        zoom: 15,
        mapTypeId: @google.maps.MapTypeId.HYBRID
      })

      infowindow = new @google.maps.InfoWindow({
        content: "Venue name here"
      })
      this._createMarker(44.476788, -73.211696)
  
  handleSearch: (term, distance) ->
    that = this
    if term and distance
      geocoder = new @google.maps.Geocoder()
      geocoder.geocode( { 'address': term}, (results, status) ->
        if status == @google.maps.GeocoderStatus.OK
          that._setCenter results[0].geometry.location
          that._createMarker(results[0].geometry.location.lat, results[0].geometry.location.lng)
        else
          @util.feedback { 'type': 'alert', 'msg': "Geocode was not successful for the following reason: #{status}" }
      )

    else
      @util.feedback { 'type': 'alert', 'msg': 'Provide a term and a distance'}
  
  _setCenter: (location) ->
    @map.setCenter location

  _createMarker: (lat, lng) ->
    marker = new @google.maps.Marker({
      position: new @google.maps.LatLng(lat, lng),
      map: @map
    })
 
 