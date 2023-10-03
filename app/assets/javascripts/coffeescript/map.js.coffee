class @Map

  constructor: ->
    @init             = true
    @markers          = []
    @popups           = []
    @map              = {}
    @view_circle      = {}
    @util             = App.Util
    @default_lng      = -73.21 # Burlington, VT
    @default_lat      = 44.47 # Burlington, VT
    @mapbox_token   = 'pk.eyJ1IjoicGhpc2hpbiIsImEiOiJjanE0cWlzYmIxd245NDNzYjR1MHV2aGExIn0.UeKqNVoqRBqYKjfLshbShw'

  initMap: ->
    if container = $('#map').get(0)
      mapboxgl.accessToken = @mapbox_token;
      @map = new mapboxgl.Map({
        container: 'map',
        style: 'mapbox://styles/phishin/cko29xhcz1i5x17plt8xwxofm',
        center: [@default_lng, @default_lat],
        zoom: 11
      });
      nav = new mapboxgl.NavigationControl()
      @map.addControl(nav, 'top-right');

  handleSearch: (term, distance) ->
    distance = parseFloat distance
    if term and distance > 0
      $.get({
        url: "https://api.mapbox.com/geocoding/v5/mapbox.places/#{term}.json?access_token=#{@mapbox_token}",
        success: (r) =>
          if r.features[0]
            this._geocodeSuccess(r, distance)
          else
            @util.feedback { alert: "Mapbox returned no results" }
      })
    else
      @util.feedback { alert: 'Provide a term and a distance'}

  _geocodeSuccess: (r, distance) ->
    this._clearAllMarkers()
    center = r.features[0].center
    @map.easeTo(center: center)

    # Fetch venues and draw markers
    $.get({
      url: "/search-map?lng=#{center[0]}&lat=#{center[1]}&distance=#{distance}&date_start=#{$('#map_date_start').val()}&date_stop=#{$('#map_date_stop').val()}",
      success: (r) =>
        if r.success
          this._drawVenues r.venues
          this._fitMapBounds r.venues
        else
          @util.feedback { alert: 'No shows match your criteria' }
    })

  _fitMapBounds: (venues) ->
    lat1 = 90
    lat2 = -90
    lng1 = 180
    lng2 = -180
    for venue in venues
      lat1 = venue.latitude if venue.latitude < lat1
      lat2 = venue.latitude if venue.latitude > lat2
      lng1 = venue.longitude if venue.longitude < lng1
      lng2 = venue.longitude if venue.longitude > lng2
    @map.fitBounds([[lng1, lat1], [lng2, lat2]], {
      padding: { top: 25, bottom: 25, left: 25, right: 25 }
    });

  _drawVenues: (venues) ->
    for venue in venues
      html = "<h1><a href=\"/#{venue.slug}\">#{venue.name}</a></h1>"
      html += "<h2><i>Also known as #{venue.other_names.join(', ')}</i></h2>" if venue.other_names.length > 0
      html += "<h2>#{venue.location}</h2>"
      word = 'show'
      if venue.shows_count != 1
        word += 's'
      html += "<h3>#{venue.shows_count} #{word}:</h3><ul>"
      for show in venue.shows
        html += "<li><a href=\"/#{show.date}\">#{show.date}</a></li>"
      html += "</ul>"
      this._createMarkerWithPopup venue.longitude, venue.latitude, html

  _createMarkerWithPopup: (lng, lat, popup_html) ->
    popup = new mapboxgl.Popup()
      .setLngLat([lng, lat])
      .setHTML(popup_html)
      .addTo(@map);

    marker = new mapboxgl.Marker()
      .setLngLat([lng, lat])
      .setPopup(popup)
      .addTo(@map);

    @markers.push(marker)
    @popups.push(popup)

  _clearAllMarkers: ->
    for popup in @popups
      popup.remove()
    for marker in @markers
      marker.remove()
    @popups = []
    @markers = []
