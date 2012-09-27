# Google Maps Web App
# Copyright (C) ICHIKAWA, Yuji (New 3 Rs) 2012

latlng = new google.maps.LatLng 35.757794, 139.876819

myOptions =
    zoom: 16,
    center: latlng,
    mapTypeId: google.maps.MapTypeId.ROADMAP
    disableDefaultUI: true

image = new google.maps.MarkerImage 'img/bluedot.png', null, null, new google.maps.Point( 8, 8 ), new google.maps.Size( 17, 17 )
myMarker = null
    
map = new google.maps.Map document.getElementById("map"), myOptions
geocoder = new google.maps.Geocoder()

$('#gps').on 'click', ->
    navigator.geolocation.getCurrentPosition (position) ->
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

$('#address').on 'change', ->
    geocoder.geocode {address : this.value }, (result, status) ->
        if status is google.maps.GeocoderStatus.OK
            map.setCenter result[0].geometry.location
        else
            alert status
