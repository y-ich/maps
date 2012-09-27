# Google Maps Web App
# Copyright (C) ICHIKAWA, Yuji (New 3 Rs) 2012

latlng = new google.maps.LatLng 35.757794, 139.876819

myOptions =
    zoom: 16,
    center: latlng,
    mapTypeId: google.maps.MapTypeId.ROADMAP
    disableDefaultUI: true
    
map = new google.maps.Map document.getElementById("map"), myOptions
geocoder = new google.maps.Geocoder()

$('#gps').on 'click', ->
    navigator.geolocation.getCurrentPosition (position) ->
        map.setCenter new google.maps.LatLng(position.coords.latitude,position.coords.longitude)

$('#address').on 'change', ->
    geocoder.geocode {address : this.value }, (result, status) ->
        if status is google.maps.GeocoderStatus.OK
            map.setCenter result[0].geometry.location
        else
            alert status
