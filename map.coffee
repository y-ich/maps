# Google Maps Web App
# Copyright (C) ICHIKAWA, Yuji (New 3 Rs) 2012

watchId = null # id for watchPosition
traceHeadingEnable = false

geocoder = null
map = null
pulsatingMarker = null
directionsService = null
directionsRenderer = null

initializeGoogleMaps = ->
    mapOptions =
        mapTypeId: google.maps.MapTypeId.ROADMAP
        disableDefaultUI: true
    # if previous position data exists, then restore it, otherwise default value.
    if localStorage['last']?
        last = JSON.parse localStorage['last']
        mapOptions.center = new google.maps.LatLng last.lat, last.lng
        mapOptions.zoom = last.zoom
    else
        mapOptions.center = new google.maps.LatLng 35.660389, 139.729225
        mapOptions.zoom = 14

    geocoder = new google.maps.Geocoder()
    map = new google.maps.Map document.getElementById("map"), mapOptions
    directionsService = new google.maps.DirectionsService()
    directionsRenderer = new google.maps.DirectionsRenderer()
    directionsRenderer.setMap map
    
    droppedMarker = new google.maps.Marker
        map: map
        position: mapOptions.center
        title: 'ドロップされたピン'
        visible: false
    startMarker = null
    destinationMarker = null

    google.maps.event.addListener map, 'click', (event) ->
        droppedMarker.setVisible true
        droppedMarker.setPosition event.latLng

    # This is a workaround for web app on home screen. There is no onpagehide event.
    google.maps.event.addListener map, 'center_changed', () ->
        pos = map.getCenter()
        localStorage['last'] = JSON.stringify { lat: pos.lat(), lng: pos.lng(), zoom: map.getZoom() }

    google.maps.event.addListener map, 'zoom_changed', () ->
        pos = map.getCenter()
        localStorage['last'] = JSON.stringify { lat: pos.lat(), lng: pos.lng(), zoom: map.getZoom() }
    

    google.maps.event.addListener droppedMarker, 'click', (event) ->
        new google.maps.StreetViewService().getPanoramaByLocation droppedMarker.getPosition(), 49, getLocationHandler

    getLocationHandler = (data, status) ->
        switch status
            when google.maps.StreetViewStatus.OK
                sv = map.getStreetView()
                sv.setPosition data.location.latLng
                droppedMarker.setPosition data.location.latLng
                sv.setPov
                    heading: map.getHeading() ? 0
                    pitch: 0
                    zoom: 1
                sv.setVisible true
            when google.maps.StreetViewStatus.ZERO_RESULTS
                alert "近くにストリートビューが見つかりませんでした。"
            else
                alert "すいません、エラーが起こりました。"

traceHandler = (position) ->
    latLng = new google.maps.LatLng position.coords.latitude,position.coords.longitude
    if pulsatingMarker
        pulsatingMarker.setPosition latLng
    else
        pulsatingMarker = new google.maps.Marker
            flat: true
            icon: new google.maps.MarkerImage('img/bluedot.png', null, null, new google.maps.Point(8, 8), new google.maps.Size(17, 17))
            map: map
            optimized: false
            position: latLng
            title: 'I might be here'
            visible: true
    map.setCenter latLng
    if traceHeadingEnable and position.coords.heading?
        transform = $map.css('-webkit-transform')
        if /rotate(-?[\d.]+deg)/.test(transform)
            transform = transform.replace(/rotate(-?[\d.]+deg)/, "rotate(#{-position.coords.heading}deg)")
        else
            transform = transform + " rotate(#{-position.coords.heading}deg)"
        $map.css('-webkit-transform', transform)

initializeDOM = ->
    squareSize = Math.floor(Math.sqrt(Math.pow(innerWidth, 2) + Math.pow(innerHeight, 2)))
    $map = $('#map')
    $map.width(squareSize)
        .height(squareSize)
        .css('margin', - squareSize / 2 + 'px')
        
    $gps = $('#gps')
    $gps.data 'status', 'normal' 
    $gps.on 'click', ->
        switch $gps.data 'status'
            when 'normal'
                $gps.data 'status', 'trace-position'
                $gps.addClass 'btn-primary'            
                traceHeadingEnable = false
                watchId = navigator.geolocation.watchPosition traceHandler
                    , (error) ->
                        console.log error.message
                    , { enableHighAccuracy: true, timeout: 30000 }
            when 'trace-position'
                $gps.data 'status', 'trace-heading'
                traceHeadingEnable = true
                $gps.children('i').removeClass 'icon-globe'       
                $gps.children('i').addClass 'icon-hand-up'
            when 'trace-heading'
                navigator.geolocation.clearWatch watchId
                watchId = null
                $gps.data 'status', 'normal'
                $map.css '-webkit-transform', $map.css('-webkit-transform').replace(/\s*rotate(-?[\d.]+deg)/, '')
                $gps.removeClass 'btn-primary'  
                $gps.children('i').removeClass 'icon-hand-up'
                $gps.children('i').addClass 'icon-globe'          
            
    $('#address').on 'change', ->
        geocoder.geocode {address : this.value }, (result, status) ->
            if status is google.maps.GeocoderStatus.OK
                map.setCenter result[0].geometry.location
            else
                alert status
    
    $navi = $('#navi')
    $search = $('#search')
    $search.on 'click', ->
        $route.removeClass 'btn-primary'
        $search.addClass 'btn-primary'
        $navi.toggle()
    $route = $('#route')
    $route.on 'click', ->
        $search.removeClass 'btn-primary'
        $route.addClass 'btn-primary'
        $navi.toggle()

    $edit = $('#edit')
    $versatile = $('#versatile')
    $routeSearchFrame = $('#route-search-frame')
    $edit.on 'click', ->
        if $edit.text() == '編集'
            $edit.text 'キャンセル'
            $versatile.text '経路'
            $routeSearchFrame.css 'top', '0px'
        else
            $edit.text '編集'
            $versatile.text '出発'
            $routeSearchFrame.css 'top', ''

    $versatile.on 'click', ->
        if $versatile.text() == '経路'
            $edit.text '編集'
            $versatile.text '出発'
            $routeSearchFrame.css 'top', ''
            
            directionsService.route
                    destination: $('#destination').val()
                    origin: $('#origin').val()
                    travelMode: google.maps.TravelMode.WALKING
                , (result, status) ->
                    switch status
                        when google.maps.DirectionsStatus.OK
                            directionsRenderer.setDirections result


    window.onpagehide = ->
        navigator.geolocation.clearWatch watchId unless watchId
        pos = map.getCenter()
        localStorage['last'] = JSON.stringify { lat: pos.lat(), lng: pos.lng(), zoom: map.getZoom() }

initializeGoogleMaps()
initializeDOM()
