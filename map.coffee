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
$originField = null
$destinationField = null
pinRowHeight = null

mapFSM = null
bookmarkContext = null

bookmarks = []
history = []

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
        google.maps.event.addListener @marker, 'click', (event) =>
            currentBookmark = @
            @showInfoWindow()

    showInfoWindow: () ->
        infoWindow.setContent makeInfoMessage @marker.getTitle(), @address        
        infoWindow.open map, @marker
        
    toObject: () ->
        pos = @marker.getPosition()
        {
            lat: pos.lat()
            lng: pos.lng()
            title: @marker.getTitle()
            address: @address
        }

# functions 

# saves current state into localStorage
saveMapStatus = () ->
    pos = map.getCenter()
    localStorage['maps-map-status'] = JSON.stringify
        lat: pos.lat()
        lng: pos.lng()
        zoom: map.getZoom()

saveOtherStatus = () ->
    localStorage['maps-other-status'] = JSON.stringify
        origin: $originField.val()
        destination: $destinationField.val()
        bookmarks: bookmarks.map (e) -> e.toObject()
        history: history

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
    origin = $originField.val()
    destination = $destinationField.val()
    return if origin is '' or destination is ''
    history.unshift
        type: 'route'
        origin: origin
        destination: destination
    searchDirections.service.route
            destination: destination
            origin: origin
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


setInfoPage = (bookmark, dropped) ->
    title = bookmark.marker.getTitle()
    position = bookmark.marker.getPosition()
    $('#info-name').text title
    $('#bookmark-name input[name="bookmark-name"]').val if dropped then bookmark.address else title
    $('#info-address').text bookmark.address
    # $('#delete-pin').css 'display', if dropped then 'block' else 'none'
    $('#send-place').attr 'href', "mailto:?subject=#{title}&body=<a href=\"https://maps.google.co.jp/maps?q=#{position.lat()},#{position.lng()}\">#{title}</a>"

generateBookmarkList = ->
    list = '<tr><td data-object-name="pulsatingMarker">現在地</td></tr>'
    list += '<tr><td data-object-name="droppedBookmark">ドロップされたピン</td></tr>' if droppedBookmark.marker.getVisible()
    list += "<tr><td data-object-name=\"bookmarks[#{i}]\">#{e.marker.getTitle()}</td></tr>" for e, i in bookmarks
    list += Array(Math.max(1, Math.floor(innerHeight / pinRowHeight) - bookmarks.length)).join '<tr><td></td></tr>'
    $('#pin-list').html list
    
generateHistoryList = ->
    print = (e) ->
        switch e.type
            when 'search'
                "検索: #{e.address}"
            when 'route'
                "出発: #{e.origin}<br>到着: #{e.destination}"
    list = ''
    list += "<tr><td data-object-name=\"history[#{i}]\">#{print e}</td></tr>" for e, i in history
    list += Array(Math.max(1, Math.floor(innerHeight / pinRowHeight) - history.length)).join '<tr><td></td></tr>'
    $('#pin-list').html list
# handlers

# NOTE: This handler is a method, not a function.
searchAddress = (address)->
    history.unshift
        type: 'search'
        address: address
    geocoder.geocode {address : address }, (result, status) ->
        if status is google.maps.GeocoderStatus.OK
            map.setCenter result[0].geometry.location
        else
            alert status

getPanoramaHandler = (data, status) ->
    switch status
        when google.maps.StreetViewStatus.OK
            sv = map.getStreetView()
            sv.setPosition data.location.latLng
            currentBookmark.marker.setPosition data.location.latLng
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
    if localStorage['maps-map-status']?
        mapStatus = JSON.parse localStorage['maps-map-status']
        mapOptions.center = new google.maps.LatLng mapStatus.lat, mapStatus.lng
        mapOptions.zoom = mapStatus.zoom
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
        currentBookmark = droppedBookmark
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
    google.maps.event.addListener map, 'center_changed', saveMapStatus
    google.maps.event.addListener map, 'zoom_changed', saveMapStatus



initializeDOM = ->
    $originField = $('#origin input[name="origin"]')
    $destinationField = $('#destination input[name="destination"]')
    $routeSearchFrame = $('#route-search-frame')
    
    pinRowHeight = $('#pin-list tr').height()

    document.addEventListener 'touchmove', (event) ->
        event.preventDefault()
    $('#pin-list-frame').on 'touchmove', (event) ->
        event.stopPropagation()
    
    # restore
    if localStorage['maps-other-status']?
        otherStatus = JSON.parse localStorage['maps-other-status']
        if otherStatus.origin? and otherStatus.origin isnt ''
            $originField.val(otherStatus.origin) 
                        .siblings('.btn-bookmark').css('display', 'none')
        if otherStatus.destination? and otherStatus.destination isnt ''
            $destinationField.val(otherStatus.destination)
                             .siblings('.btn-bookmark').css('display', 'none')
        for e in otherStatus.bookmarks ? []
            bookmarks.push new Bookmark new google.maps.Marker(
                    map: map
                    position: new google.maps.LatLng e.lat, e.lng
                    title: e.title
                ), e.address
        history = otherStatus.history ? []

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
            
    $('#address').on 'submit', ->
        address = $(this).children('input').val()
        searchAddress address if address? and address isnt ''
        return false 

    $('.search-query').on 'keyup', -> # textInput, keypress is before inputting a character.
        $this = $(this)
        if $this.val() is ''
            $this.siblings('.btn-bookmark').css('display', 'block')
        else
            $this.siblings('.btn-bookmark').css('display', 'none')

    $('.btn-reset').on 'click', ->
        $(this).siblings('.btn-bookmark').css('display', 'block')        
    
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
        $destinationField.val $originField.val()
        $originField.val tmp
        saveOtherStatus()

    $originField.on 'change', saveOtherStatus
    $destinationField.on 'change', saveOtherStatus

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
        setInfoPage(currentBookmark, currentBookmark is droppedBookmark)
        $('#container').css 'right', '100%'

    $('#button-map').on 'click', ->
        $('#container').css 'right', ''
        
    $('.btn-bookmark').on 'click', ->
        bookmarkContext = $(this).parent().attr 'id'
        generateBookmarkList()
        $('#window-bookmark').css 'bottom', '0'
    
    $('#bookmark-done').on 'click', ->
        $('#window-bookmark').css 'bottom', '-100%'
    
    $(document).on 'click', '#pin-list td', ->
        name = $(this).data('object-name')
        return unless name? and name isnt ''
        if /history/.test name # history list
            null # need to implement
        else # bookmark list
            bookmarkOrMarker = eval(name)
            switch bookmarkContext
                when 'address'
                    map.getStreetView().setVisible(false)
                    if name is 'pulsatingMarker'
                        mapFSM.currentPositionClicked()
                    else
                        currentBookmark = bookmarkOrMarker
                        map.setCenter bookmarkOrMarker.marker.getPosition()
                        bookmarkOrMarker.showInfoWindow()
                when 'origin'
                    $originField.val if name is 'pulsatingMarker'
                            latLng = bookmarkOrMarker.getPosition()
                            "#{latLng.lat()}, #{latLng.lng()}"
                        else
                            bookmarkOrMarker.address            
                when 'destination'
                    $destinationField.val if name is 'pulsatingMarker'
                            latLng = bookmarkOrMarker.getPosition()
                            "#{latLng.lat()}, #{latLng.lng()}"
                        else
                            bookmarkOrMarker.address            

        $('#window-bookmark').css 'bottom', '-100%'

    $('#add-bookmark').on 'click', ->
        $('#info-add-window').css 'top', '0'

    $('#cancel-add-bookmark').on 'click', ->
        $('#info-add-window').css 'top', ''

    $('#delete-pin').on 'click', ->
        if currentBookmark is droppedBookmark
            droppedBookmark.marker.setVisible false
        else
            index = bookmarks.indexOf currentBookmark
            bookmarks.splice index, 1
            currentBookmark.marker.setMap null
        infoWindow.close()
        $('#container').css 'right', ''
        
    $('#save-bookmark').on 'click', ->
        bookmark = new Bookmark new google.maps.Marker(
                map: map
                position: currentBookmark.marker.getPosition()
                title: $('#bookmark-name input[name="bookmark-name"]').val()
            ), $('#info-address').text() 
        bookmarks.push bookmark
        bookmark.showInfoWindow()
        saveOtherStatus()
        $('#info-add-window').css 'top', ''
        $('#container').css 'right', ''


    $('#nav-bookmark button').on 'click', ->
        $this = $(this)
        $('#nav-bookmark button').removeClass 'btn-primary'
        $this.addClass 'btn-primary'
        switch $this.attr 'id'
            when 'bookmark'
                $('#bookmark-message').text 'マップ上に表示するブックマークを選択'
                $('#bookmark-edit').text('編集')
                                   .addClass 'disabled'
                generateBookmarkList()
            when 'history'
                $('#bookmark-message').text '検索履歴を選択'
                $('#bookmark-edit').text('消去')
                                   .removeClass 'disabled'
                generateHistoryList()
            
    watchPosition = new WatchPosition().start traceHandler
        , (error) -> console.log error.message
        , { enableHighAccuracy: true, timeout: 30000 }

    window.onpagehide = ->
        watchPosition.stop()
        saveMapStatus()
        saveOtherStatus()

initializeGoogleMaps()
initializeDOM()

