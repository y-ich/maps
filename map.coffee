# Google Maps Web App
# Copyright (C) ICHIKAWA, Yuji (New 3 Rs) 2012

watchId = null
traceHeadingEnable = false

latlng = if localStorage['position']?
        position = JSON.parse localStorage['position']
        new google.maps.LatLng position.lat, position.lng
    else
        new google.maps.LatLng 35.660389,139.729225

myOptions =
    zoom: 16,
    center: latlng,
    mapTypeId: google.maps.MapTypeId.ROADMAP
    disableDefaultUI: true

geocoder = new google.maps.Geocoder()
map = new google.maps.Map document.getElementById("map"), myOptions
window.map = map

image = new google.maps.MarkerImage 'img/bluedot.png', null, null, new google.maps.Point( 8, 8 ), new google.maps.Size( 17, 17 )
myMarker = null
marker = new google.maps.Marker
    map: map
    position: latlng
    title: 'ドロップされたピン'
    visible: false

google.maps.event.addListener map, 'click', (event) ->
    marker.setVisible true
    marker.setPosition event.latLng

google.maps.event.addListener marker, 'click', (event) ->
    new google.maps.StreetViewService().getPanoramaByLocation marker.getPosition(), 49, getLocationHandler

getLocationHandler = (data, status) -> 
    switch status
        when google.maps.StreetViewStatus.OK
            sv = map.getStreetView()
            sv.setPosition data.location.latLng
            marker.setPosition data.location.latLng
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
    latLng = new google.maps.LatLng(position.coords.latitude,position.coords.longitude)
    if myMarker
        myMarker.setPosition latLng
    else
        myMarker = new google.maps.Marker
            flat: true
            icon: image
            map: map
            optimized: false
            position: latLng
            title: 'I might be here'
            visible: true
    map.setCenter latLng
    map.setHeading position.coords.heading if traceHeadingEnable

$('#map').height window.innerHeight - $('#header').outerHeight(true) - $('#footer').outerHeight(true)

$gps = $('#gps')
$gps.data 'status', 'normal' 
$gps.on 'click', ->
    switch $gps.data 'status'
        when 'normal'
            $gps.addClass 'btn-primary'            
            traceHeadingEnable = false
            map.setHeading 0
            watchId = navigator.geolocation.watchPosition traceHandler
                , (error) ->
                    console.log error.message
                , { enableHighAccuracy: true, timeout: 30000 }
            $gps.data 'status', 'trace-position'
        when 'trace-position'
            # traceHeadingEnable = true
            $gps.addClass 'disabled'            
            $gps.children('i').removeClass 'icon-globe'       
            $gps.children('i').addClass 'icon-hand-up'
            $gps.data 'status', 'trace-heading'
        when 'trace-heading'
            navigator.geolocation.clearWatch watchId
            watchId = null
            map.setHeading 0
            $gps.removeClass 'btn-primary'  
            $gps.children('i').removeClass 'icon-hand-up'
            $gps.children('i').addClass 'icon-globe'          
            $gps.data 'status', 'normal'
            
$('#address').on 'change', ->
    geocoder.geocode {address : this.value }, (result, status) ->
        if status is google.maps.GeocoderStatus.OK
            map.setCenter result[0].geometry.location
        else
            alert status

window.onpagehide = ->
    navigator.geolocation.clearWatch watchId unless watchId
    pos = map.getCenter()
    localStorage['position'] = JSON.stringify {lat: pos.lat(), lng: pos.lng()}
