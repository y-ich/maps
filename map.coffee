# Google Maps Web App
# Copyright (C) ICHIKAWA, Yuji (New 3 Rs) 2012

# constants

PURPLE_DOT_IMAGE = 'http://maps.google.co.jp/mapfiles/ms/icons/purple-dot.png'
RED_DOT_IMAGE = 'http://maps.google.co.jp/mapfiles/ms/icons/red-dot.png'

# global variables

# Google Maps services
map = null
geocoder = null
directionsRenderer = null

pulsatingMarker = null
droppedBookmark = null
currentBookmark = null
infoWindow = null
naviMarker = null

# jQuery instances
$map = null
$gps = null
$origin = null
$destination = null

mapFSM = null
bookmarkContext = null

bookmarks = []
searchHistory = []
routeHistory = []

# classes

# manages id for navigator.geolocation
class WatchPosition
    start: () ->
        @id = navigator.geolocation.watchPosition.apply navigator.geolocation, Array.prototype.slice.call(arguments)
        @

    stop: () ->
        navigator.geolocation.clearWatch @id unless @id
        @id = null
        @

# abstract class for map's state
# Concrete instances are class constant.
class MapState
    constructor: (@name)-> 

    # concrete instances
    @NORMAL: new MapState('normal')
    @TRACE_POSITION: new MapState('trace_position')
    @TRACE_HEADING: new MapState('trace_heading')

    # all methods should return a state for a kind of delegation
    update: -> @
    gpsClicked: -> @
    moved: -> @
    bookmarkClicked: -> @
    currentPositionClicked: -> @

MapState.NORMAL.update = ->
    $map.css '-webkit-transform', $map.css('-webkit-transform').replace(/\s*rotate(-?[\d.]+deg)/, '')
    $gps.removeClass('btn-primary')
    # need to restore icon if implementing TRACE_HEADING
    @
MapState.NORMAL.gpsClicked = -> MapState.TRACE_POSITION
MapState.NORMAL.currentPositionClicked = -> MapState.TRACE_POSITION

MapState.TRACE_POSITION.update = ->
    $gps.addClass 'btn-primary'
    @
MapState.TRACE_POSITION.gpsClicked = -> MapState.NORMAL # disabled TRACE_HEADING
MapState.TRACE_POSITION.moved = -> MapState.NORMAL

MapState.TRACE_HEADING.update = ->
    # need to change icon
    @
MapState.TRACE_HEADING.gpsClicked = -> MapState.NORMAL
MapState.TRACE_HEADING.moved = -> MapState.NORMAL
MapState.TRACE_HEADING.bookmarkClicked = -> MapState.TRACE_POSITION

class MapFSM
    constructor: (@state) ->

    is: (state) -> @state is state

    setState: (state) ->
        return if @state is state
        @state = state
        @state.update()

for name, method of MapState.prototype when typeof method is 'function'
    MapFSM.prototype[name] = ((name) ->
        -> this.setState this.state[name]())(name) # substantiation of name



class Bookmark
    constructor: (@marker, @address) ->

        
# functions 

# saves current state into localStorage
saveStatus = () ->
    pos = map.getCenter()
    localStorage['last'] = JSON.stringify
        lat: pos.lat()
        lng: pos.lng()
        zoom: map.getZoom()
        origin: $origin.val()
        destination: $destination.val()

# sums after some transformation
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


makeInfoMessage = (name, message) ->
    """
    <table id="info-window"><tr>
        <td><button id="street-view" class="btn"><i class="icon-user"></i></button></td>
        <td style="white-space: nowrap;"><div>#{name}<br><span id="dropped-message" style="font-size:10px">#{message}</span></div></td>
        <td><button id="button-info" class"btn"><i class="icon-chevron-right"></i></button></td>
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


setInfoPage = (bookmark, deleteButton = false) ->
    $('#info-name').text bookmark.marker.getTitle()
    $('#bookmark-name').val bookmark.marker.getTitle()
    $('#info-address').text bookmark.address
    $('#info-delete-pin').css 'display', if deleteButton then 'block' else 'none'
    
# handlers

# NOTE: This handler is a method, not a function.
geocodeHandler = ->
    return if this.value is ''
    geocoder.geocode {address : this.value }, (result, status) ->
        if status is google.maps.GeocoderStatus.OK
            map.setCenter result[0].geometry.location
        else
            alert status

getPanoramaHandler = (data, status) ->
    switch status
        when google.maps.StreetViewStatus.OK
            sv = map.getStreetView()
            sv.setPosition data.location.latLng
            droppedBookmark.marker.setPosition data.location.latLng # need to change
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
    map.setCenter latLng unless mapFSM.is MapState.NORMAL
    if mapFSM.is MapState.TRACE_HEADING and position.coords.heading?
        transform = $map.css('-webkit-transform')
        if /rotate(-?[\d.]+deg)/.test(transform)
            transform = transform.replace(/rotate(-?[\d.]+deg)/, "rotate(#{-position.coords.heading}deg)")
        else
            transform = transform + " rotate(#{-position.coords.heading}deg)"
        $map.css('-webkit-transform', transform)

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
    mapFSM = new MapFSM(MapState.NORMAL)
    geocoder = new google.maps.Geocoder()
    directionsRenderer = new google.maps.DirectionsRenderer()
    directionsRenderer.setMap map
    google.maps.event.addListener directionsRenderer, 'directions_changed', ->
        navigate.leg = null
        navigate.step = null
        $('#navi-toolbar2').css 'display', 'none'
        naviMarker.setVisible false

    droppedBookmark = new Bookmark new google.maps.Marker
        map: map
        position: mapOptions.center
        title: 'ドロップされたピン'
        visible: false
    currentBookmark = droppedBookmark
    
    infoWindow = new google.maps.InfoWindow
        maxWidth: innerWidth
        
    startMarker = null
    destinationMarker = null

    naviMarker = new google.maps.Marker
        flat: true
        icon: new google.maps.MarkerImage('img/bluedot.png', null, null, new google.maps.Point(8, 8), new google.maps.Size(17, 17))
        map: map
        optimized: false
        visible: false

    google.maps.event.addListener map, 'click', (event) ->
        droppedBookmark.marker.setVisible true
        droppedBookmark.marker.setPosition event.latLng
        infoWindow.setContent makeInfoMessage droppedBookmark.marker.getTitle(), ''
        infoWindow.open map, droppedBookmark.marker
        geocoder.geocode {latLng : event.latLng }, (result, status) ->
            droppedBookmark.address = if status is google.maps.GeocoderStatus.OK
                    result[0].formatted_address.replace(/日本, /, '')
                else
                    '情報がみつかりませんでした。'
            infoWindow.setContent makeInfoMessage droppedBookmark.marker.getTitle(), droppedBookmark.address

    google.maps.event.addListener map, 'dragstart', -> mapFSM.moved()
    # This is a workaround for web app on home screen. There is no onpagehide event.
    google.maps.event.addListener map, 'center_changed', saveStatus
    google.maps.event.addListener map, 'zoom_changed', saveStatus

    google.maps.event.addListener droppedBookmark.marker, 'click', (event) ->
        infoWindow.setContent makeInfoMessage droppedBookmark.marker.getTitle(), droppedBookmark.address        
        infoWindow.open map, droppedBookmark.marker


initializeDOM = ->
    $origin = $('#origin')
    $destination = $('#destination')
    $routeSearchFrame = $('#route-search-frame')
    
    pinRowHeight = $('#pin-list tr').height()

    document.addEventListener 'touchmove', (event) ->
        event.preventDefault()
    $('#pin-list-frame').on 'touchmove', (event) ->
        event.stopPropagation()
    
    # restore
    if localStorage['last']?
        last = JSON.parse localStorage['last']
        if last.origin? and last.origin isnt ''
            $origin.val(last.origin) 
                   .siblings('.btn-bookmark').css('display', 'none')
        if last.destination? and last.destination isnt ''
            $destination.val(last.destination)
                        .siblings('.btn-bookmark').css('display', 'none')

    # layouts
    
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
    $gps.on 'click', -> mapFSM.gpsClicked()
            
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
        droppedBookmark.marker.setPosition map.getCenter()
        droppedBookmark.marker.setVisible true
        backToMap()

    $('#print').on 'click', ->
        setTimeout window.print, 0
        backToMap()
        
    $(document).on 'click', '#street-view', (event) ->
        new google.maps.StreetViewService().getPanoramaByLocation currentBookmark.marker.getPosition(), 49, getPanoramaHandler

    $(document).on 'click', '#button-info', (event) ->
        setInfoPage(currentBookmark, true)
        $('#container').css 'right', '100%'

    $('#button-map').on 'click', ->
        $('#container').css 'right', ''
        
    $('.btn-bookmark').on 'click', ->
        bookmarkContext = $(this).siblings('input').attr 'id'
        mapFSM.bookmarkClicked() if bookmarkContext is 'address'
        list = '<tr><td data-object-name="pulsatingMarker">現在地</td></tr>'
        list += '<tr><td data-object-name="droppedBookmark.marker">ドロップされたピン</td></tr>' if droppedBookmark.marker.getVisible()
        list += Array(Math.floor(innerHeight / pinRowHeight) - bookmarks.length).join '<tr><td></td></tr>'
        $('#pin-list').html list
        $('#window-bookmark').css 'bottom', '0'
    
    $('#bookmark-done').on 'click', ->
        $('#window-bookmark').css 'bottom', '-100%'
    
    $('#pin-list td').on 'click', ->
        name = $(this).data('object-name')
        return unless name? and name isnt ''
        switch bookmarkContext
            when 'address'
                if name is 'pulsatingMarker'
                    mapFSM.currentPositionClicked()
#            when 'origin'
#            when 'destination'
        $('#window-bookmark').css 'bottom', '-100%'

    $('#add-bookmark').on 'click', ->
        $('#info-add-window').css 'top', '0'

    $('#cancel-add-bookmark').on 'click', ->
        $('#info-add-window').css 'top', ''

    $('#delete-pin').on 'click', ->
        droppedBookmark.marker.setVisible false
        infoWindow.close()
        $('#container').css 'right', ''
        
    $('save-bookmark').on 'click', ->
        
    
    watchPosition = new WatchPosition().start traceHandler
        , (error) -> console.log error.message
        , { enableHighAccuracy: true, timeout: 30000 }

    window.onpagehide = ->
        watchPosition.stop()
        saveStatus()

initializeGoogleMaps()
initializeDOM()

