# Google Maps Web App
# Copyright (C) ICHIKAWA, Yuji (New 3 Rs) 2012

map = null
geocoder = null
pulsatingMarker = null
droppedMarker = null
droppedInfo = null
naviMarker = null
directionsRenderer = null
$origin = $('#origin')
$destination = $('#destination')
bookmarkContext = 'address'


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

# returns current map type on display
getMapType = -> google.maps.MapTypeId[$('#map-type').children('.btn-primary').attr('id').toUpperCase()]


makeInfoMessage = (message) ->
    """
    <table id="info-window"><tr>
        <td><button id="street-view" class="btn"><i class="icon-user"></i></button></td>
        <td style="white-space: nowrap;"><div>ドロップされたピン<br><span id="dropped-message" style="font-size:10px">#{message}</span></div></td>
        <td><button id="info" class"btn disabled"><i class="icon-chevron-right"></i></button></td>
    </tr></table>
    """


# invokes to search directions and displays a result.
searchDirections = ->
    searchDirections.service.route
            destination: $('#destination').val()
            origin: $('#origin').val()
            provideRouteAlternatives: getTravelMode() isnt google.maps.TravelMode.WALKING
            travelMode: getTravelMode()
        , (result, status) ->
            $message = $('#message')
            message = ''
            window.result = result
            switch status
                when google.maps.DirectionsStatus.OK
                    directionsRenderer.setMap map
                    directionsRenderer.setDirections result
                    index = directionsRenderer.getRouteIndex()
                    message += "候補経路：全#{result.routes.length}件中#{index + 1}件目<br>" if result.routes.length > 1
                    distance = mapSum result.routes[index].legs, (e) -> e.distance.value
                    duration = mapSum result.routes[index].legs, (e) -> e.duration.value
                    summary = "#{secondToString duration}〜#{meterToString distance}〜#{result.routes[index].summary}"
                    if summary.length > innerWidth / parseInt($message.css('font-size')) # assuming the unit is px.
                        summary = "#{result.routes[index].summary}<br>#{secondToString duration}〜#{meterToString distance}"
                    message += summary
                    $('#message').html message
                when google.maps.DirectionsStatus.ZERO_RESULTS
                    directionsRenderer.setMap null
                    $('#message').html "経路が見つかりませんでした。"
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


# handlers

# NOTE: This handler is a method, not a function.
geocodeHandler = ->
    return if this.value is ''
    geocoder.geocode {address : this.value }, (result, status) ->
        if status is google.maps.GeocoderStatus.OK
            map.setCenter result[0].geometry.location
        else
            alert status

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
    if traceHandler.heading and position.coords.heading?
        transform = $map.css('-webkit-transform')
        if /rotate(-?[\d.]+deg)/.test(transform)
            transform = transform.replace(/rotate(-?[\d.]+deg)/, "rotate(#{-position.coords.heading}deg)")
        else
            transform = transform + " rotate(#{-position.coords.heading}deg)"
        $map.css('-webkit-transform', transform)
traceHandler.heading = false
traceHandler.id = null

# initializations

initializeGoogleMaps = ->
    mapOptions =
        mapTypeId: getMapType()
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
    geocoder = new google.maps.Geocoder()
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
    droppedInfo = new google.maps.InfoWindow
        disableAutoPan: true
        maxWidth: innerWidth
    droppedInfo.open map, droppedMarker
        
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
        droppedInfo.setContent makeInfoMessage ''
        geocoder.geocode {latLng : event.latLng }, (result, status) ->
            message = if status is google.maps.GeocoderStatus.OK
                    result[0].formatted_address.replace(/日本, /, '').replace(/.*〒[\d-]+/, '')
                else
                    'ドロップされたピン</br>情報がみつかりませんでした。'
            droppedInfo.setContent makeInfoMessage message

    # This is a workaround for web app on home screen. There is no onpagehide event.
    google.maps.event.addListener map, 'center_changed', saveStatus
    google.maps.event.addListener map, 'zoom_changed', saveStatus


initializeDOM = ->
    document.addEventListener 'touchmove', (event) ->
        event.preventDefault()
    $('#pin-list-frame').on 'touchmove', (event) ->
        event.stopPropagation()
    
    # restore
    if localStorage['last']?
        last = JSON.parse localStorage['last']
        $('#origin').val(last.origin) if last.origin?
        $('#destination').val(last.destination) if last.destination?

    # layouts
    
    $(document.body).css 'padding-top', $('#header').outerHeight(true) # padding corespondent with header
    $('#option-container').css 'bottom', $('#footer').outerHeight(true)
    $map = $('#map')
# disabled heading trace
#    squareSize = Math.floor(Math.sqrt(Math.pow(innerWidth, 2) + Math.pow(innerHeight, 2)))
#    $map.width(squareSize)
#        .height(squareSize)
#        .css('margin', - squareSize / 2 + 'px')
    $map.height innerHeight - $('#header').outerHeight(true) - $('#footer').outerHeight(true)
    $('#pin-list-frame').css 'height', innerHeight - mapSum($('#window-bookmark .btn-toolbar').toArray(), (e) -> $(e).outerHeight(true)) + 'px'


    # event handlers

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
            
    $('.search-query').parent().on 'submit', ->
        return false
        
    $('#address').on 'change', geocodeHandler
    $('.search-query').on 'keyup', -> # textInput, keypress is before inputting a character.
        $this = $(this)
        if $this.val() is ''
            $this.siblings('.btn-bookmark').css('display', 'block')
        else
            $this.siblings('.btn-bookmark').css('display', 'none')
    
    
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

    backToMap = ->
        $map.css 'top', ''
        $option.removeClass 'btn-primary'
        
    $option = $('#option')
    $option.on 'click', ->
        $('#option-container').css 'display', 'block' # option-container is not visible in order to let startup clear.

        if $option.hasClass 'btn-primary'
            backToMap()
        else
            $map.css 'top', - $('#option-container').outerHeight(true) + 'px'
            $option.addClass 'btn-primary'

    $mapType = $('#map-type')
    $mapType.children(':not(#panel)').on 'click', ->
        $this = $(this)
        return if $this.hasClass 'btn-primary'
        $mapType.children().removeClass 'btn-primary'
        $this.addClass 'btn-primary'
        map.setMapTypeId getMapType()
        backToMap()

    $traffic = $('#traffic')
    trafficLayer = new google.maps.TrafficLayer()
    $traffic.on 'click', ->
        if $traffic.text() is '渋滞状況を表示'
            trafficLayer.setMap map
            $traffic.text '渋滞状況を隠す'
        else
            trafficLayer.setMap null
            $traffic.text '渋滞状況を表示'
        backToMap()

    $('#replace-pin').on 'click', ->
        droppedMarker.setPosition map.getCenter()
        droppedMarker.setVisible true
        backToMap()

    $('#print').on 'click', ->
        setTimeout window.print, 0
        backToMap()
        
    $(document).on 'click', '#street-view', (event) ->
        new google.maps.StreetViewService().getPanoramaByLocation droppedMarker.getPosition(), 49, getLocationHandler

    $('.btn-bookmark').on 'click', ->
        bookmarkContext = $(this).siblings('input').attr 'id'
        $('#window-bookmark').css 'bottom', '0'
    
    $('#bookmark-done').on 'click', ->
        $('#window-bookmark').css 'bottom', '-100%'
    
    $('#pin-list td').on 'click', ->
        name = $(this).data('object-name')
        return unless name? and name isnt ''
#        switch bookmarkContext
#            when 'address'
#                if name is 'pulsatingMarker'
#                    startTrace()
#            when 'origin'
#            when 'destination'
        $('#window-bookmark').css 'bottom', '-100%'
            
    window.onpagehide = ->
        navigator.geolocation.clearWatch traceHandler.id unless traceHandler.id
        saveStatus()

initializeGoogleMaps()
initializeDOM()
