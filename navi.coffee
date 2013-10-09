map = null
home = new google.maps.LatLng(34.584305, 135.83521)
destination = new google.maps.LatLng 34.529284,135.797228
$map = $('#map')
directionsRenderer = null
watchId = null
navigationMode = false

say = (string) ->
        MAX_LENGTH = 100
        audio = new WAudio "translate_tts?tl=#{lang}&q=#{encodeURIComponent string[0...MAX_LENGTH]}"
        audio.play()

route = (origin, destination, callback = ->) ->
    route.service.route
            avoidHighways: true
            avoidTolls: true
            destination: destination
            origin: origin
            provideRouteAlternatives: true
            travelMode: google.maps.TravelMode.DRIVING
        , (result, status) ->
            if status is google.maps.DirectionsStatus.OK
                directionsRenderer = new google.maps.DirectionsRenderer
                    directions: result
                    map: map
                    panel: $('#panel')[0]
                    routeIndex: 0
                callback result
            else
                alert status
route.service = new google.maps.DirectionsService()

rotationMap = ->
    $('#tilt').addClass 'tilt'
    r = Math.ceil Math.sqrt(innerWidth * innerWidth + innerHeight * innerHeight)
    $map.css 'width', r + 'px'
    $map.css 'height', r + 'px'
    $map.css 'left', - (r - innerWidth) / 2 + 'px'
    $map.css 'top', - (r - innerHeight) / 2 + 'px'
    map.setOptions draggable: false
    google.maps.event.trigger map, 'resize'

normalMap = ->
    $('#tilt').removeClass 'tilt'
    $map.css 'width', ''
    $map.css 'height', ''
    $map.css 'left', ''
    $map.css 'top', ''
    $map.css '-webkitTransform', ''
    $map.css 'display', ''
    map.setOptions draggable: true
    google.maps.event.trigger map, 'resize'


startWatch = ->
    rotationMap()
    map.setZoom 18
    lastTime = new Date().getTime()
    watchId = navigator.geolocation.watchPosition ((position) ->
        now = new Date().getTime()
        latLng = new google.maps.LatLng position.coords.latitude, position.coords.longitude
        map.setCenter latLng

        if position.coords.heading? and position.coords.speed?
            latLng = google.maps.geometry.spherical.computeOffset latLng, position.coords.speed * (now - lastTime) / 1000, position.coords.heading

        new google.maps.StreetViewService().getPanoramaByLocation latLng, 49, (data, status) ->
            if status is google.maps.StreetViewStatus.OK
                sv = map.getStreetView()
                sv.setPosition data.location.latLng
                $map.css 'display', 'none'
            else
                $map.css 'display', ''
        for leg in directionsRenderer.getDirections().routes[directionsRenderer.getRouteIndex()].legs
            for step in leg.steps
                if google.maps.geometry.spherical.computeDistanceBetween(latLng, step.start_location) < 50
                    unless step.passed?
                        say $("<div>#{step.instructions}</div>").text().replace(/\s/g, '').replace(/（.*?）/g, '')
                        step.passed = true
        lastTime = now
    ), (->),
        enableHighAccuracy: true
        timeout: 60000

window.ondeviceorientation = (event) ->
    if watchId?
        map.getStreetView().setPov
            heading: event.webkitCompassHeading
            pitch: 0
        $map.css '-webkitTransform', "rotateZ(#{-event.webkitCompassHeading}deg)"

window.onpagehide = ->
    navigator.geolocation.clearWatch watchId if watchId?

window.onpageshow = -> startWatch() if watchId?

window.onorientationchange = -> rotationMap() if watchId?

autocomplete = new google.maps.places.Autocomplete $('#search > form > input')[0]
google.maps.event.addListener autocomplete, 'place_changed', ->
    place = autocomplete.getPlace()
    if place.geometry?
        route home, place.geometry.location, ->
            $('#start-stop').removeAttr 'disabled'

$('#search form').on 'submit', (event) ->
    event.preventDefault()

$('#start-stop').on 'click', (event) ->
    if watchId?
        navigator.geolocation.clearWatch watchId
        watchId = null
        $('#silent')[0].pause()
        normalMap()
        $('#panel').css 'display', ''
        $(this).text 'Navi'
    else
        $('#panel').css 'display', 'none'
        WAudio.unlock()
        $('#silent')[0].play()
        startWatch()
        $(this).text 'Stop'

navigator.geolocation.getCurrentPosition ((position) ->
    map = new google.maps.Map $map[0],
        center: new google.maps.LatLng(position.coords.latitude, position.coords.longitude)
        zoom: 14
        mapTypeId: google.maps.MapTypeId.ROADMAP
        streetView: new google.maps.StreetViewPanorama($('#street-view')[0],
            visible: true
        )
)

$(document).on 'touchmove', (event) -> event.preventDefault()
