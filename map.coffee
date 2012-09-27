# Google Maps Web App
# Copyright (C) ICHIKAWA, Yuji (New 3 Rs) 2012

latlng = new google.maps.LatLng 35.757794, 139.876819

myOptions =
    zoom: 16,
    center: latlng,
    mapTypeId: google.maps.MapTypeId.ROADMAP
    disableDefaultUI: true
    
map = new google.maps.Map document.getElementById("map"), myOptions
