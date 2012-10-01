# Google Maps Web App
# Copyright (C) ICHIKAWA, Yuji (New 3 Rs) 2012

map = null
pulsatingMarker = null
naviMarker = null
directionsRenderer = null
$origin = $('#origin')
$destination = $('#destination')


mapSum = (array, fn) ->
    array.map(fn).reduce (a, b) -> a + b

# returns formatted string '?日?時間?分' from sec(number)
secondToString = (sec) ->
    result = ''
    min = Math.floor(sec / 60)
    sec -= min * 60
    hour = Math.floor(min / 60)
    min -= hour * 60
    day = Math.floor(hour / 24)
    hour -= day * 24
    result += day + '日' if day > 0
    result += hour + '時間' if hour > 0 and day < 10
    result += min + '分' if min > 0 and day == 0 and hour < 10
    result
    

# returns formatted string '?km' or '?m' from sec(number)
meterToString = (meter) ->
    if meter < 1000
        meter + 'm'
    else
        parseFloat((meter / 1000).toPrecision(2)) + 'km'


# returns current travel mode on display
getTravelMode = -> google.maps.TravelMode[$('#travel-mode').children('.btn-primary').attr('id').toUpperCase()]


# invokes to search directions and displays a result.
searchDirections = ->
    searchDirections.service.route
            destination: $('#destination').val()
            origin: $('#origin').val()
            travelMode: getTravelMode()
        , (result, status) ->
            switch status
                when google.maps.DirectionsStatus.OK
                    directionsRenderer.setMap map
                    directionsRenderer.setDirections result
                    distance = mapSum result.routes[0].legs, (e) -> e.distance.value
                    duration = mapSum result.routes[0].legs, (e) -> e.duration.value
                    switch getTravelMode()
                        when google.maps.TravelMode.WALKING
                            $('#message').html("#{secondToString duration}〜#{meterToString distance}〜#{result.routes[0].summary}")
                        when google.maps.TravelMode.DRIVING
                            $('#message').html("#{result.routes[0].summary}<br>#{secondToString duration}〜#{meterToString distance}")
                when google.maps.DirectionsStatus.ZERO_RESULTS
                    directionsRenderer.setMap null
                    $('#message').html("見つかりませんでした。")
                else
                    directionsRenderer.setMap null
                    console.log status
searchDirections.service = new google.maps.DirectionsService()

saveStatus = () ->
    pos = map.getCenter()
    localStorage['last'] = JSON.stringify
        lat: pos.lat()
        lng: pos.lng()
        zoom: map.getZoom()
        origin: $origin.val()
        destination: $destination.val()


navigate = (str) ->
    route = directionsRenderer.getDirections()?.routes[directionsRenderer.getRouteIndex()]
    return unless route?
    switch str
        when 'start'
            navigate.leg = 0
            navigate.step = 0
            $('#navi-toolbar2').css 'display', 'block'
            naviMarker.setVisible true
        when 'next'
            if navigate.step < route.legs[navigate.leg].steps.length - 1
                navigate.step += 1
            else if navigate.leg < route.legs.length - 1
                navigate.leg += 1            
                navigate.step = 0
        when 'previous'
            if navigate.step > 0
                navigate.step -= 1
            else if navigate.leg > 0
                navigate.leg -= 1
                navigate.step = route.legs[navigate.leg].steps.legth - 1
        
    map.setZoom 15
    step = route.legs[navigate.leg].steps[navigate.step]
    naviMarker.setPosition step.start_location
    map.setCenter step.start_location
    lengths = (route.legs.map (e) -> e.steps.length)
    steps = if navigate.leg == 0 then navigate.step else lengths[0...navigate.leg].reduce (a, b) -> a + b
    $('#numbering').text (steps + 1) + '/' + (route.legs.map (e) -> e.steps.length).reduce (a, b) -> a + b
    $('#message').html step.instructions

navigate.leg = null
navigate.step = null


geocodeHandler = ->
    geocodeHandler.geocoder.geocode {address : this.value }, (result, status) ->
        if status is google.maps.GeocoderStatus.OK
            map.setCenter result[0].geometry.location
        else
            alert status
geocodeHandler.geocoder = new google.maps.Geocoder()

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

    map = new google.maps.Map document.getElementById("map"), mapOptions
    directionsRenderer = new google.maps.DirectionsRenderer()
    directionsRenderer.setMap map
    google.maps.event.addListener directionsRenderer, 'directions_changed', ->
        navigate.leg = null
        navigate.step = null
        $('#navi-toolbar2').css 'display', 'none'
        naviMarker.setVisible false
        
    
    droppedMarker = new google.maps.Marker
        map: map
        position: mapOptions.center
        title: 'ドロップされたピン'
        visible: false
    startMarker = null
    destinationMarker = null

    naviMarker = new google.maps.Marker
        flat: true
        icon: new google.maps.MarkerImage('img/bluedot.png', null, null, new google.maps.Point(8, 8), new google.maps.Size(17, 17))
        map: map
        optimized: false
        visible: false

    google.maps.event.addListener map, 'click', (event) ->
        droppedMarker.setVisible true
        droppedMarker.setPosition event.latLng

    # This is a workaround for web app on home screen. There is no onpagehide event.
    google.maps.event.addListener map, 'center_changed', saveStatus
    google.maps.event.addListener map, 'zoom_changed', saveStatus
    
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

    google.maps.event.addListener droppedMarker, 'click', (event) ->
        new google.maps.StreetViewService().getPanoramaByLocation droppedMarker.getPosition(), 49, getLocationHandler


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
    if traceHandler.heading and position.coords.heading?
        transform = $map.css('-webkit-transform')
        if /rotate(-?[\d.]+deg)/.test(transform)
            transform = transform.replace(/rotate(-?[\d.]+deg)/, "rotate(#{-position.coords.heading}deg)")
        else
            transform = transform + " rotate(#{-position.coords.heading}deg)"
        $map.css('-webkit-transform', transform)
traceHandler.heading = false
traceHandler.id = null


initializeDOM = ->
    $(document.body).css 'padding-top', $('#header').outerHeight(true) # padding corespondent with header

    if localStorage['last']?
        last = JSON.parse localStorage['last']
        $('#origin').val(last.origin) if last.origin?
        $('#destination').val(last.destination) if last.destination?
        

    $map = $('#map')
# disabled heading trace
#    squareSize = Math.floor(Math.sqrt(Math.pow(innerWidth, 2) + Math.pow(innerHeight, 2)))
#    $map.width(squareSize)
#        .height(squareSize)
#        .css('margin', - squareSize / 2 + 'px')
    $map.height innerHeight - $('#header').outerHeight(true) - $('#footer').outerHeight(true)
        
    $gps = $('#gps')
    $gps.data 'status', 'normal' 
    $gps.on 'click', ->
        switch $gps.data 'status'
            when 'normal'
                $gps.data 'status', 'trace-position'
                $gps.addClass 'btn-primary'            
                traceHandler.heading = false
                traceHandler.id = navigator.geolocation.watchPosition traceHandler
                    , (error) ->
                        console.log error.message
                    , { enableHighAccuracy: true, timeout: 30000 }
            when 'trace-position'
# disabled trace-heading
#                $gps.data 'status', 'trace-heading'
#                traceHandler.heading = true
#                $gps.children('i').removeClass 'icon-globe'       
#                $gps.children('i').addClass 'icon-hand-up'
#            when 'trace-heading'
                navigator.geolocation.clearWatch traceHandler.id
                traceHandler.id = null
                $gps.data 'status', 'normal'
                $map.css '-webkit-transform', $map.css('-webkit-transform').replace(/\s*rotate(-?[\d.]+deg)/, '')
                $gps.removeClass 'btn-primary'  
                $gps.children('i').removeClass 'icon-hand-up'
                $gps.children('i').addClass 'icon-globe'          
            
    $('#address').on 'change', geocodeHandler
    
    $navi = $('#navi')
    $search = $('#search')
    $search.on 'click', ->
        directionsRenderer.setMap null
        naviMarker.setVisible false
        $route.removeClass 'btn-primary'
        $search.addClass 'btn-primary'
        $navi.toggle()
    $route = $('#route')
    $route.on 'click', ->
        $search.removeClass 'btn-primary'
        $route.addClass 'btn-primary'
        $navi.toggle()
        directionsRenderer.setMap map

    $edit = $('#edit')
    $versatile = $('#versatile')
    $routeSearchFrame = $('#route-search-frame')
    $edit.on 'click', ->
        if $edit.text() == '編集'
            $edit.text 'キャンセル'
            $versatile.text '経路'
            $('#navi-toolbar2').css 'display', 'none'
            $routeSearchFrame.css 'top', '0px'
        else
            $edit.text '編集'
            $versatile.text '出発'
            $('#navi-toolbar2').css 'display', 'block' if navigate.leg? and navigate.step?
            $routeSearchFrame.css 'top', ''

    $('#edit2').on 'click', ->
        $edit.trigger 'click'

    $('#switch').on 'click', ->
        tmp = $('#destination').val()
        $('#destination').val $('#origin').val()
        $('#origin').val tmp
        saveStatus()

    $('#origin, #destination').on 'changed', saveStatus

    $travelMode = $('#travel-mode')
    $travelMode.children(':not(#transit)').on 'click', -> # disabled transit
        $this = $(this)
        return if $this.hasClass 'btn-primary'
        $travelMode.children().removeClass 'btn-primary'
        $this.addClass 'btn-primary'
        searchDirections()
        
    $versatile.on 'click', ->
        switch $versatile.text()
            when '経路'
                $edit.text '編集'
                $versatile.text '出発'
                $routeSearchFrame.css 'top', ''
                searchDirections()
            when '出発'
                navigate 'start'

    $('#cursor-left').on 'click', -> navigate 'previous'
    $('#cursor-right').on 'click', -> navigate 'next'       

    window.onpagehide = ->
        navigator.geolocation.clearWatch traceHandler.id unless traceHandler.id
        saveStatus()

initializeGoogleMaps()
initializeDOM()
