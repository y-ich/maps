# Google Maps Web App
# Copyright (C) 2012-2103 ICHIKAWA, Yuji (New 3 Rs) 

#
# global variables
#

# constants
PURPLE_DOT_IMAGE = 'http://maps.google.co.jp/mapfiles/ms/icons/purple-dot.png'
RED_DOT_IMAGE = 'http://maps.google.co.jp/mapfiles/ms/icons/red-dot.png'
MSMARKER_SHADOW = 'http://maps.google.co.jp/mapfiles/ms/icons/msmarker.shadow.png'

# Google Maps services
map = null
geocoder = null
directionsRenderer = null
transitLayer = null
trafficLayer = null
bicycleLayer = null
panoramioLayer = null
kmlLayer = null
fusionLayer = null
autoAddressField = null
autoOriginField = null
autoDestinationField = null

currentPlace = null # is a pin of current position
naviMarker = null # is a pin navigating a route.
infoWindow = null # general purpose singlton of InfoWindow

droppedPlace = null # combination of dropped marker and address information
searchPlace = null # search result
placeContext = null # context place
centerBeforeSV = null

norikaeServices = [
    ['MapFan+', 'mapfanplus:', '', '']
    ['乗換ナビ', 'navitimetransfer:', '', '']
    ['乗換案内', 'NrkjFree:', '', '']
    ['Yahoo! ロコ 乗換案内', 'yjtransit:']
    ['駅.Locky', 'com.ubigraph.ekilocky:']
    ['Google乗換案内', 'https://www.google.co.jp/maps?ie=UTF8&f=d&dirflg=r&', 'saddr', 'daddr']
    ['ジョルダン', 'http://www.jorudan.co.jp/norikae/cgi/nori.cgi?', 'eki1', 'eki2']
]

# jQuery instances
$map = null
$gps = null
$addressField = null
$originField = null
$destinationField = null
$pinList = null
$message = null

# layout parameter
pinRowHeight = null
scrollLeft = false

# state variables
mapFSM = null
bookmarkContext = null
bookmarks = [] # an array of Place instances
history = [] # an array of Object instances. two formats. { type: 'search', address: }, { type: 'route', origin: ,destination: }
maxHistory = 20 # max number of history
isHold = true # hold detection of touch. default is true for desktop

#
# classes
#

# manages id for navigator.geolocation
tracer =
    START: 0
    NORMAL: 1
    DISABLED: 2
    UNAVAILABLE: 3
    TIMEOUT: 4
    state: 0 # START
    watchId: null

    start: ->
        @watchId = navigator.geolocation.watchPosition @success
            , @error
            ,
                enableHighAccuracy: true
                timeout: 60000
        @setState @START

    stop: ->
        navigator.geolocation.clearWatch @watchId unless @watchId
        @watchId = null

    setState: (state) ->
        if @state isnt state
            @state = state
            mapFSM.tracerChanged()

    success: (position) ->
        latLng = new google.maps.LatLng position.coords.latitude,position.coords.longitude
        currentPlace.marker.setVisible true
        currentPlace.marker.setPosition latLng
        currentPlace.marker.setRadius position.coords.accuracy
        currentPlace.address = null # because current address may become old.
        map.setCenter latLng unless mapFSM.is MapState.NORMAL
        tracer.setState tracer.NORMAL

    error: (error) ->
        console.log error
        switch error.code
            when error.PERMISSION_DENIED
                tracer.stop()
                tracer.setState tracer.DISABLED
            when error.POSITION_UNAVAILABLE
                tracer.setState tracer.UNAVAILABLE
            when error.TIMEOUT
                tracer.setState tracer.TIMEOUT

# abstract class for map's trace state
# Concrete instances are class constant.
class MapState
    constructor: (@name)->

    # concrete instances
    @DISABLED: new MapState('disabled')
    @NORMAL: new MapState('normal')
    @TRACE_START: new MapState('trace_start')
    @TRACE_POSITION: new MapState('trace_position')
    @UNAVAILABLE: new MapState('unavailable')
    @TIMEOUT: new MapState('timout')

    # all methods should return a state for a kind of delegation
    update: (fsm) -> @
    gpsClicked: -> @
    bookmarkClicked: -> @
    tracerChanged: ->
        switch tracer.state
            when tracer.DISABLED
                MapState.DISABLED
            else
                @


tracer2State = ->
    switch tracer.state
        when tracer.START
            MapState.TRACE_START
        when tracer.NORMAL
            MapState.TRACE_POSITION
        when tracer.DISABLED
            MapState.DISABLED
        when tracer.UNAVAILABLE
            MapState.UNAVAILABLE
        when tracer.TIMEOUT
            MapState.TIMEOUT
        else
            console.log 'unknown tracer state'
            @

MapState.DISABLED.update = ->
    $gps.removeClass('btn-light')
        .addClass('disabled')
    @

MapState.NORMAL.update = ->
    $gps.removeClass('btn-light')
    @

MapState.NORMAL.gpsClicked = tracer2State

MapState.TRACE_START.update = (fsm) ->
    fsm.timerId = setInterval (-> $gps.toggleClass 'btn-light'), 250
    @

MapState.TRACE_START.gpsClicked = (fsm) ->
    clearInterval fsm.timerId
    fsm.timerId = null
    MapState.NORMAL

MapState.TRACE_START.tracerChanged = (fsm) ->
    clearInterval fsm.timerId
    fsm.timerId = null
    tracer2State()

MapState.TRACE_POSITION.update = ->
    map.setCenter currentPlace.marker.getPosition() if currentPlace.marker.getVisible()
    $gps.addClass 'btn-light'
    @

MapState.TRACE_POSITION.gpsClicked = -> MapState.NORMAL

MapState.TRACE_POSITION.tracerChanged = tracer2State

MapState.UNAVAILABLE.update = (fsm) ->
    fsm.timerId = setInterval (-> $gps.toggleClass 'btn-light'), 1000
    @

MapState.UNAVAILABLE.gpsClicked = (fsm) ->
    clearInterval fsm.timerId
    fsm.timerId = null
    MapState.NORMAL

MapState.UNAVAILABLE.tracerChanged = (fsm) ->
    clearInterval fsm.timerId
    fsm.timerId = null
    tracer2State()

MapState.TIMEOUT.update = (fsm) ->
    fsm.timerId = setInterval (-> $gps.toggleClass 'btn-light'), 2000
    @

MapState.TIMEOUT.gpsClicked = MapState.UNAVAILABLE.gpsClicked

MapState.TIMEOUT.tracerChanged = (fsm) ->
    clearInterval fsm.timerId
    fsm.timerId = null
    tracer2State()


# state machine for map
class MapFSM
    constructor: (@state) ->
        @timerId = null

    is: (state) -> @state is state

    setState: (state) ->
        return if @state is state
        @state = state
        @state.update(@)
# delegate
for name, method of MapState.prototype when typeof method is 'function'
    MapFSM.prototype[name] = ((name) ->
        -> @setState @state[name](@))(name) # substantiation of name



# is a class with a marker and an address and responsible for InfoWindow.
class Place
    @_streetViewService: new google.maps.StreetViewService()
    @_streetViewButtonWrapper: $('<div class="button-wrapper wrapper-left"></div>').on('click', (event) -> # ,(comma) out of parenthesis causes parser error.
        event.stopPropagation()
        if placeContext.svLatLng?
            centerBeforeSV = map.getCenter()
            infoWindow.close()
            $('#map-page').addClass 'streetview'
            google.maps.event.trigger map, 'resize'
            map.setOptions streetViewControl: true
            map.setCenter placeContext.svLatLng
            sv = map.getStreetView()
            sv.setPosition placeContext.svLatLng
            sv.setPov
                heading: map.getHeading() ? 0
                pitch: 0
                zoom: 1
            sv.setVisible true
    )
    @_infoButtonWrapper: $('<div class="button-wrapper wrapper-right"></div>').on('click', ->
        setInfoPage(placeContext, placeContext is droppedPlace)
        $('body').animate {scrollLeft: innerWidth}, 300
        scrollLeft = true
    )

    # constructs an instance from marker and address, gets address if missed, gets Street View info and sets event listener.
    constructor: (@marker, @address) ->
        @update()
        google.maps.event.addListener @marker, 'click', (event) =>
            placeContext = @
            @showInfoWindow()
            @update() unless @address?

    update: ->
        if not @address?
            geocoder.geocode {latLng : @marker.getPosition() }, (result, status) =>
                @address = if status is google.maps.GeocoderStatus.OK
                        result[0].formatted_address.replace(/日本, /, '')
                    else
                        getLocalizedString 'No information'
                $droppedMessage = $('#dropped-message')
                if placeContext is @ and $('#info-window').length == 1 and $droppedMessage.text() isnt @address
                    $droppedMessage.text @address 

        Place._streetViewService.getPanoramaByLocation @marker.getPosition(), 49, (data, status) =>
            if status is google.maps.StreetViewStatus.OK
                @svLatLng = data.location.latLng
                $('#sv-button').addClass 'btn-primary' if placeContext is @ and $('#info-window').length == 1


    # shows its InfoWindow.
    showInfoWindow: ->
        @_setInfoWindow()
        infoWindow.open map, @marker

    # plain object to JSONize.
    toObject: () ->
        pos = @marker.getPosition()
        {
            lat: pos.lat()
            lng: pos.lng()
            title: @marker.getTitle()
            address: @address
        }

    _setInfoWindow: ->
        $container = $('<div>')
        $container.html """
                        <table id="info-window"><tr>
                            <td>
                                <button id="sv-button" class="btn btn-mini#{if @svLatLng? then ' btn-primary' else ''}">
                                    <i class="icon-user icon-white"></i>
                                </button>
                            </td>
                            <td style="white-space: nowrap;"><div style="max-width:160px;overflow:hidden;">#{@marker.getTitle()}<br><span id="dropped-message" style="font-size:10px">#{@address}</span></div></td>
                            <td>
                                <button id="button-info" class="btn btn-mini btn-light">
                                    <i class="icon-chevron-right icon-white"></i>
                                </button>
                            </td>
                        </tr></table>
                        """
        infoWindow.setContent $container.append(Place._streetViewButtonWrapper, Place._infoButtonWrapper)[0]


#
# function definitions
#


# general

# sums in an array
sum = (array) ->
    array.reduce (a, b) -> a + b

# sums after some transformation
mapSum = (array, fn) ->
    array.map(fn).reduce (a, b) -> a + b

# returns ordinal number as String
ordinal = (n) ->
    tens = n.toString().slice(0, -1)
    switch n % 20
        when 1
            tens + '1st'
        when 2
            tens + '2nd'
        when 3
            tens + '3rd'
        else
            n + 'th'


parseQuery = (str) ->
    equations = str.replace(/^\?|\s+$/,'').split '&'
    result= {}
    for e in equations
        pair = e.split '='
        result[pair[0]] = decodeURIComponent pair[1]
    result

# localize functions

# getRouteindexMessage, getDepartAtMessage, getArriveAtMessage should be defined in js for localization.

window.getRouteIndexMessage ?= (index, total) ->
    "#{ordinal(index + 1)} of #{total} Suggested Routes"

window.getDepartAtMessage ?= (time) ->
    'Departs at ' + time

window.getArriveAtMessage ?= (time) ->
    'Arrives at ' + time

getLocalizedString = (key) ->
    if localizedStrings? then localizedStrings[key] ? key else key

setLocalExpressionInto = (id, english) ->
    document.getElementById(id).lastChild.data = getLocalizedString english

localize = ->
    idWordPairs =
        'replace-pin' : 'Replace Pin'
        'print' : 'Print'
        'traffic' : 'Show Traffic'
        'panoramio' : 'Show Panoramio'
        'roadmap' : 'Standard'
        'satellite' : 'Satellite'
        'panel' : 'List'
        'hybrid' : 'Hybrid'
        'clear' : 'Clear'
        'map-title' : 'Search'
        'done' : 'Done'
        'edit' : 'Edit'
        'versatile' : 'Start'
        'origin-label' : 'Start: '
        'destination-label' : 'End: '
        'edit2' : 'Edit'
        'search' : 'Search'
        'route' : 'Directions'
        'bookmark-message' : 'Choose a bookmark to view on the map'
        'bookmark-edit' : 'Edit'
        'bookmark-done' : 'Done'
        'bookmark-title' : 'Bookmarks'
        'bookmark' : 'Bookmarks'
        'history' : 'Recents'
        'contact' : 'Contacts'
        'button-map' : 'Map'
        'info-title' : 'Info'
        'address-label' : 'address'
        'to-here' : 'Directions To Here'
        'from-here' : 'Directions From Here'
        'remove-pin' : 'Remove Pin'
        'add-into-contact' : 'Add to Contacts'
        'send-place' : 'Share Location'
        'add-bookmark' : 'Add to Bookmarks'
        'add-bookmark-message' : 'Type a name for the bookmark'
        'cancel-add-bookmark' : 'Cancel'
        'add-bookmark-title' : 'Add Bookmark'
        'save-bookmark' : 'Save'
        'edit3' : 'Edit'
        'directions-title' : 'Directions'

    document.title = getLocalizedString 'Maps'
    document.getElementById('search-input').placeholder = getLocalizedString 'Search or Address'
    setLocalExpressionInto key, value for key, value of idWordPairs


# saves current state into localStorage
# saves frequently changing state
saveMapStatus = () ->
    pos = map.getCenter()
    localStorage['maps-map-status'] = JSON.stringify
        lat: pos.lat()
        lng: pos.lng()
        zoom: map.getZoom()

# saves others
saveOtherStatus = () ->
    history.splice maxHistory
    localStorage['maps-other-status'] = JSON.stringify
        address: $addressField.val()
        origin: $originField.val()
        destination: $destinationField.val()
        bookmarks: bookmarks.map (e) -> e.toObject()
        history: history

# returns formatted string '?日?時間?分' from sec(number)
secondToString = (sec) ->
    result = ''
    min = Math.floor(sec / 60)
    sec -= min * 60
    hour = Math.floor(min / 60)
    min -= hour * 60
    day = Math.floor(hour / 24)
    hour -= day * 24

    result += if day == 1 then day + getLocalizedString('day') else if day > 1 then day + getLocalizedString('days') else ''    
    if day < 10
        result += if hour == 1 then hour + getLocalizedString('hour') else if hour > 1 then hour + getLocalizedString('hours') else ''
    if day == 0 and hour < 10
        result += if min == 1 then min + getLocalizedString('minute') else if min > 1 then min + getLocalizedString('minutes') else ''

    result

# returns formatted string '?km' or '?m' from sec(number)
meterToString = (meter) ->
    if meter < 1000
        meter + 'm'
    else
        parseFloat((meter / 1000).toPrecision(2)) + 'km'

# returns current travel mode on display
getTravelMode = -> google.maps.TravelMode[$('#travel-mode > .btn-primary').attr('id').toUpperCase()]

# returns current map type on display
getMapType = -> google.maps.MapTypeId[$('#map-type > .btn-primary').attr('id').toUpperCase()]


setSearchResult = (place) ->
    directionsRenderer.setMap null

    latLng = currentPlace.marker.getPosition()
    updateField $originField, "#{latLng.lat()}, #{latLng.lng()}"
    updateField $destinationField, place.formatted_address

    mapFSM.setState MapState.NORMAL
    if 'viewport' in place.geometry and place.geometry.viewport?
        map.fitBounds place.geometry.viewport
    else
        map.setCenter place.geometry.location
    searchPlace.address = place.formatted_address
    searchPlace.marker.setPosition place.geometry.location
    searchPlace.marker.setTitle place.name ? $addressField.val()
    searchPlace.marker.setVisible true
    searchPlace.marker.setAnimation google.maps.Animation.DROP
    placeContext = searchPlace

setRouteMap = ->
    travelMode = getTravelMode()
    trafficLayer.setMap if travelMode is google.maps.TravelMode.DRIVING then map else null
    transitLayer.setMap if travelMode is google.maps.TravelMode.TRANSIT then map else null
    bicycleLayer.setMap if travelMode is google.maps.TravelMode.BICYCLING then map else null
    if getMapType() is google.maps.MapTypeId.ROADMAP
        if travelMode is google.maps.TravelMode.WALKING or travelMode is google.maps.TravelMode.BICYCLING
            map.setMapTypeId google.maps.MapTypeId.TERRAIN
        else
            map.setMapTypeId google.maps.MapTypeId.ROADMAP

prepareKmlLayer = (address) ->
    kmlLayer.setMap null if kmlLayer?
    kmlLayer = new google.maps.KmlLayer address, map: map
    google.maps.event.addListener kmlLayer, 'status_changed', ->
        return if kmlLayer.getStatus() is google.maps.KmlLayerStatus.OK
        switch kmlLayer.getStatus()
            when google.maps.KmlLayerStatus.DOCUMENT_NOT_FOUND
                alert 'DOCUMENT_NOT_FOUND'
            when google.maps.KmlLayerStatus.DOCUMENT_TOO_LARGE
                alert 'DOCUMENT_TOO_LARGE'
            when google.maps.KmlLayerStatus.FETCH_ERROR
                alert 'FETCH_ERROR'
            when google.maps.KmlLayerStatus.INVALID_DOCUMENT
                alert 'INVALID_DOCUMENT'
            when google.maps.KmlLayerStatus.INVALID_REQUEST
                alert 'INVALID_REQUEST'
            when google.maps.KmlLayerStatus.LIMITS_EXCEEDED
                alert 'LIMITS_EXCEEDED'
            when google.maps.KmlLayerStatus.TIMED_OUT
                alert 'TIMED_OUT'
            when google.maps.KmlLayerStatus.UNKNOWN
                alert 'UNKNOWN'
        kmlLayer.setMap null
        kmlLayer = null

# search and display a place
searchAddress = (fromHistory) ->
    address = $addressField.val()
    return unless address? and address isnt ''
    infoWindow.close()
    searchPlace.marker.setVisible false
    if not fromHistory
        history.unshift
            type: 'search'
            address: address
        saveOtherStatus()
    if match = address.match /^fusion:(.*)/
        parameters = parseQuery match[1]
        return unless `'id' in parameters`
        fusionLayer.setMap null if fusionLayer?
        fusionLayer = new google.maps.FusionTablesLayer
            map: map
            query:
                from: parameters['id']
                select: parameters['column'] ? 'Location'
    else if /^([a-z]+):\/\//.test address
        prepareKmlLayer address
    else
        geocoder.geocode { address : address }, (result, status) ->
            switch status
                when google.maps.GeocoderStatus.OK
                    setSearchResult result[0]
                when google.maps.GeocoderStatus.ZERO_RESULTS
                    alert getLocalizedString 'No Results Found'
                else
                    alert status

updateMessage = ->
    return unless directionsRenderer.getDirections()?
    index = directionsRenderer.getRouteIndex()
    result = directionsRenderer.getDirections()
    route = result.routes[index]
    message = ''
    message += getRouteIndexMessage(index, result.routes.length) + '<br>' if result.routes.length > 1
    if getTravelMode() is google.maps.TravelMode.TRANSIT
        summary = getDepartAtMessage route.legs[0].departure_time.text
        summary += '<br>'
        summary += getArriveAtMessage route.legs[route.legs.length - 1].arrival_time.text
    else
        distance = mapSum result.routes[index].legs, (e) -> e.distance.value
        duration = mapSum result.routes[index].legs, (e) -> e.duration.value
        summary = "#{secondToString duration} - #{meterToString distance} - #{result.routes[index].summary}"
        if summary.length > innerWidth / parseInt($message.css('font-size')) # assuming the unit is px.
            summary = "#{result.routes[index].summary}<br>#{secondToString duration} - #{meterToString distance}"
    message += summary
    $message.html message


# invokes to search directions and displays a result.
searchDirections = (fromHistory = false) ->
    origin = $originField.val()
    destination = $destinationField.val()
    return unless origin? and origin isnt '' and destination? and destination isnt ''

    infoWindow.close()

    if not fromHistory
        history.unshift
            type: 'route'
            origin: origin
            destination: destination
        saveOtherStatus()

    travelMode = getTravelMode()
    searchDirections.service.route
            destination: destination
            origin: origin
            provideRouteAlternatives: getTravelMode() isnt google.maps.TravelMode.WALKING
            travelMode: travelMode
        , (result, status) ->
            switch status
                when google.maps.DirectionsStatus.OK
                    directionsRenderer.setMap map
                    directionsRenderer.setDirections result
                    updateMessage()
                else
                    directionsRenderer.setMap null
                    mode = $('#travel-mode').children('.btn-primary').attr('id')
                    mode = mode[0].toUpperCase() + mode.substr 1
                    $message.html getLocalizedString(mode + ' directions could not be found between these locations')
                    alert getLocalizedString('Directions Not Available\nDirections could not be found between these locations.') + "(#{status})"

searchDirections.service = new google.maps.DirectionsService()


# navigate current direction step by step
navigate = (str) ->
    route = directionsRenderer.getDirections()?.routes[directionsRenderer.getRouteIndex()]
    return unless route?
    switch str
        when 'start'
            navigate.leg = 0
            navigate.step = 0
            $('#navi-header2').css 'display', 'block'
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
    lengths = route.legs.map (e) -> e.steps.length
    steps = navigate.step + if navigate.leg == 0 then 0 else sum lengths[0...navigate.leg]
    $('#numbering').text (steps + 1) + '/' + mapSum route.legs, (e) -> e.steps.length
    $message.html step.instructions

navigate.leg = null
navigate.step = null


# DOM treat

# updates an input field with bookmark button
updateField = ($field, str) ->
    $field.val(str)
          .siblings('.btn-bookmark').css 'display', if str is '' then 'block' else 'none'

# prepare page of bookmark information
setInfoPage = (place, dropped) ->
    $('#info-marker img:first-child').attr 'src', place.marker.getIcon()?.url ? 'http://maps.google.co.jp/mapfiles/ms/icons/red-dot.png'
    title = place.marker.getTitle()
    position = place.marker.getPosition()
    $('#info-name').text title
    $('#bookmark-name input[name="bookmark-name"]').val if dropped then place.address else title
    $('#info-address').text place.address
    # $('#remove-pin').css 'display', if dropped then 'block' else 'none'
    # The above was commented out because editing bookmark is not implemented yet.
    $('#send-place').attr 'href', "mailto:?subject=#{title}&body=<a href=\"https://maps.google.co.jp/maps?q=#{position.lat()},#{position.lng()}\">#{title}</a>"

generateBookmarkList = ->
    list = "<tr><td data-object-name=\"currentPlace\">#{getLocalizedString 'Current Location'}</td></tr>"
    list += "<tr><td data-object-name=\"droppedPlace\">#{getLocalizedString 'Dropped Pin'}</td></tr>" if droppedPlace.marker.getVisible()
    list += "<tr><td data-object-name=\"bookmarks[#{i}]\">#{e.marker.getTitle()}</td></tr>" for e, i in bookmarks
    list += Array(Math.max(1, Math.floor(innerHeight / pinRowHeight) - bookmarks.length)).join '<tr><td></td></tr>'
    $pinList.html list

generateHistoryList = ->
    print = (e) ->
        switch e.type
            when 'search'
                getLocalizedString('Search: ') + e.address
            when 'route'
                getLocalizedString('Start: ') + e.origin + '<br>' + getLocalizedString('End: ') + e.destination
    list = ''
    list += "<tr><td data-object-name=\"history[#{i}]\">#{print e}</td></tr>" for e, i in history
    list += Array(Math.max(1, Math.floor(innerHeight / pinRowHeight) - history.length)).join '<tr><td></td></tr>'
    $pinList.html list


# initializations

initializeGoogleMaps = ->
    parameters = parseQuery location.search

    mapOptions =
        mapTypeId: getMapType()
        disableDefaultUI: true
        streetView: new google.maps.StreetViewPanorama(document.getElementById('streetview'),
            panControl: false,
            zoomControl: false,
            visible: false
        )

    google.maps.event.addListener mapOptions.streetView, 'position_changed', ->
        map.setCenter this.getPosition()

    # restore map status
    if localStorage['maps-map-status']?
        mapStatus = JSON.parse localStorage['maps-map-status']
        mapOptions.center = new google.maps.LatLng mapStatus.lat, mapStatus.lng
        mapOptions.zoom = mapStatus.zoom
    else
        mapOptions.center = new google.maps.LatLng 35.660389, 139.729225
        mapOptions.zoom = 14

    map = new google.maps.Map document.getElementById('map'), mapOptions
    map.setTilt 45
    mapFSM = new MapFSM(MapState.NORMAL)
    infoWindow = new MobileInfoWindow
        maxWidth: Math.floor innerWidth*0.9

    if `'fusionid' in parameters`
        fusionLayer = new google.maps.FusionTablesLayer
            map: map
            query:
                from: parameters['fusionid']
                select: parameters['fusioncolumn'] ? 'Location'
            styles: [
                    markerOptions:
                        iconName: parameters['fusionicon'] ? 'red_stars'
                ]

    if `'kml' in parameters`
        prepareKmlLayer parameters['kml']

    geocoder = new google.maps.Geocoder()

    autoAddressField = new google.maps.places.Autocomplete $('#address input[name="address"]')[0]
    autoAddressField.bindTo 'bounds', map
    google.maps.event.addListener autoAddressField, 'place_changed', ->
        place = autoAddressField.getPlace()
        setSearchResult place if 'geometry' of place 

    autoOriginField = new google.maps.places.Autocomplete $('#origin input[name="origin"]')[0]
    autoOriginField.bindTo 'bounds', map 

    autoDestinationField = new google.maps.places.Autocomplete $('#destination input[name="destination"]')[0]
    autoDestinationField.bindTo 'bounds', map 

    # Here is a work around for google.maps.places.Autocomplete on iOS.
    # Type Enter after Japanese IME transformation causes input value to restore the one before transformation unexpectedly.
    # The difference between desktop and iOS is keydown and keyup events after textInput(IME transformation) event.
    # There are neither keydown nor keyup on iOS.
    # So emulate this events after textInput without keydown.
    # note: textInput always happens when English. So you need check with or without keydown.
    $('input.places-auto').on 'keydown', -> $(this).data 'keydown', true
    $('input.places-auto').on 'keyup', -> $(this).data 'keydown', false
    $('input.places-auto').on 'textInput', ->
        unless $(this).data 'keydown' # if textInput without keydown
            for event in ['keydown', 'keyup']
                e = document.createEvent 'KeyboardEvent'
                e.initKeyboardEvent event, true, true, window, 'Enter', 0, ''
                this.dispatchEvent(e)

    # relace place lists after transition.
    # place lists of auto complete are placed 'absolute'ly. They doesn't take care of transition effect.
    $('#search-header, #route-search-frame').on 'webkitTransitionEnd', ->
        $this = $(this)
        $('.pac-container:visible').css 'top', $this.offset().top + $this.outerHeight(true) + 'px'

    directionsRenderer = new google.maps.DirectionsRenderer
        hideRouteList: false
        infoWindow: infoWindow
        map: map
        panel: $('#directions-panel')[0]

    google.maps.event.addListener directionsRenderer, 'directions_changed', ->
        navigate.leg = null
        navigate.step = null
        $('#navi-header2').css 'display', 'none'
        naviMarker.setVisible false

    currentPlace = new Place new MarkerWithCircle(
            flat: true
            icon: new google.maps.MarkerImage('img/bluedot.png', null, null, new google.maps.Point(8, 8), new google.maps.Size(17, 17))
            map: map
            optimized: false
            position: mapOptions.center
            title: getLocalizedString 'Current Location'
            visible: false
        ), ''

    droppedPlace = new Place new google.maps.Marker(
            animation: google.maps.Animation.DROP
            map: map
            icon: new google.maps.MarkerImage(PURPLE_DOT_IMAGE)
            shadow: new google.maps.MarkerImage(MSMARKER_SHADOW, null, null, new google.maps.Point(DEFAULT_ICON_SIZE / 2, DEFAULT_ICON_SIZE))
            position: mapOptions.center
            title: getLocalizedString 'Dropped Pin'
            visible: false
        ), ''

    searchPlace = new Place new google.maps.Marker(
            animation: google.maps.Animation.DROP
            map: map
            position: mapOptions.center
            visible: false
        ), ''

    naviMarker = new google.maps.Marker
        flat: true
        icon: new google.maps.MarkerImage('img/bluedot.png', null, null, new google.maps.Point(8, 8), new google.maps.Size(17, 17))
        map: map
        optimized: false
        visible: false

    holdInfo =
        x: null
        y: null
        id: null
    google.maps.event.addListener map, 'mousedown', (event) ->
        $infoWindow = $('.info-window')
        if $infoWindow.length > 0
            xy = infoWindow.getProjection().fromLatLngToDivPixel event.latLng
            position = $infoWindow.position()
            return if (position.left <= xy.x <= position.left + $infoWindow.outerWidth(true)) and (position.top <= xy.y <= position.top + $infoWindow.outerHeight(true))

        infoWindow.close()

        if holdInfo.id? # multi touch cause plural mousedowns before mouseup. In that case, just cancels hold behavior.
            clearTimeout holdInfo.id
            holdInfo.id = null
        else
            holdInfo.x = event.pixel.x
            holdInfo.y = event.pixel.y
            holdInfo.id = setTimeout (->
                droppedPlace.address = null
                droppedPlace.svLatLng = null
                droppedPlace.marker.setPosition event.latLng
                droppedPlace.marker.setVisible true
                droppedPlace.marker.setAnimation google.maps.Animation.DROP
                droppedPlace.update()
                placeContext = droppedPlace
            ), 500

    google.maps.event.addListener map, 'mousemove', (event) ->
        if holdInfo.id? and not ((Math.abs(event.pixel.x - holdInfo.x) < 10) and (Math.abs(event.pixel.y - holdInfo.y) < 10)) # if not a little move
            clearTimeout holdInfo.id
            holdInfo.id = null

    google.maps.event.addListener map, 'mouseup', ->
        clearTimeout holdInfo.id if holdInfo.id?
        holdInfo.id = null

    google.maps.event.addListener droppedPlace.marker, 'animation_changed', ->
        droppedPlace.showInfoWindow() if not this.getAnimation()? # animation property becomes undefined after animation ends

    google.maps.event.addListener searchPlace.marker, 'animation_changed', ->
        searchPlace.showInfoWindow() if not this.getAnimation()? # animation property becomes undefined after animation ends

    google.maps.event.addListener map, 'dragstart', -> mapFSM.setState MapState.NORMAL
    # The followings are a workaround for web app on home screen. As there is no onpagehide event, saves statuses when updated.
    google.maps.event.addListener map, 'center_changed', ->
        saveMapStatus unless map.getStreetView().getVisible()
    google.maps.event.addListener map, 'zoom_changed', saveMapStatus

    trafficLayer = new google.maps.TrafficLayer()

    transitLayer = new google.maps.TransitLayer()

    bicycleLayer = new google.maps.BicyclingLayer()

    panoramioLayer = new google.maps.panoramio.PanoramioLayer
        suppressInfoWindows: true

    google.maps.event.addListener panoramioLayer, 'click', (event) ->
        infoWindow.setPosition event.latLng
        infoWindow.setContent event.infoWindowHtml
        infoWindow.open map


initializeDOM = ->
    # initializes global variables
    $map = $('#map')
    $gps = $('#gps')
    $addressField = $('#address input[name="address"]')
    $originField = $('#origin input[name="origin"]')
    $destinationField = $('#destination input[name="destination"]')
    $message = $('#message')
    $pinList = $('#pin-list')
    pinRowHeight = $('#pin-list tr').height()

    for e in $('button').not('#clear, .btn-reset') # except '#clear, .btn-reset' because NoClickDelay prevents 'mousedown' event and causes to blur text input.
        new NoClickDelay e

    # prevents default page scroll, but scroll bookmark/history list.
    document.addEventListener 'touchmove', (event) ->
        event.preventDefault()
    $('#pin-list-frame, #info, #directions-panel').on 'touchmove', (event) ->
        event.stopPropagation()

    restoreStatus()

    #localization
    localize()
    # renders DOMs after localize
    $('#container').css 'display', ''


    #
    # event handlers
    #

    window.addEventListener 'orientationchange', (->
        # work around against unexpected page slide when rotating to portrait
        document.body.scrollLeft = if scrollLeft then innerWidth else 0
    ), false

    window.addEventListener 'resize', (->
        google.maps.event.trigger map, 'resize'
        google.maps.event.trigger map.getStreetView(), 'resize'
    ), false

    # hold detection
    $map.on 'touchstart', ->
        isHold = false
        setTimeout (-> isHold = true), 500

    # input with reset button
    $('.search-query').on 'keyup', -> # textInput, keypress is before inputting a character.
        $this = $(this)
        if $this.val() is ''
            $this.siblings('.btn-bookmark').css('display', 'block')
        else
            $this.siblings('.btn-bookmark').css('display', 'none')

    $('#clear, .btn-reset').on 'mousedown', (event) -> event.preventDefault() # prevent blur of input

    # input with bookmark icon
    $('.btn-reset').on 'click', -> $(this).siblings('.btn-bookmark').css('display', 'block')
    $('#clear').on 'click', -> $('#address .btn-bookmark').css('display', 'block')

    # footer

    $gps.on 'click', -> mapFSM.gpsClicked()

    # search header

    $addressField.on 'focus', -> $('#search-header').css 'top', '0' # down form
    $addressField.on 'blur', -> $('#search-header').css 'top', '' # up form

    $('#address').on 'submit', ->
        searchAddress(false)
        $addressField.blur()
        false # to prevent submit action

    $addressField.on 'keyup', -> setLocalExpressionInto 'done', if $(this).val() is '' then 'Done' else 'Cancel'

    $('#clear, #address .btn-reset').on 'click', ->
        setLocalExpressionInto 'done', 'Done'
        searchPlace.marker.setVisible false
        infoWindow.close() if placeContext is searchPlace

    $naviHeader = $('#navi-header1')
    $search = $('#search')
    $search.on 'click', ->
        trafficLayer.setMap null
        transitLayer.setMap null
        bicycleLayer.setMap null
        map.setMapTypeId google.maps.MapTypeId.ROADMAP if getMapType() is google.maps.MapTypeId.ROADMAP
        directionsRenderer.setMap null
        naviMarker.setVisible false
        $route.removeClass 'btn-primary'
        $search.addClass 'btn-primary'
        $naviHeader.css 'display', 'none'
    $route = $('#route')
    $route.on 'click', ->
        $search.removeClass 'btn-primary'
        $route.addClass 'btn-primary'
        $naviHeader.css 'display', 'block'
        setRouteMap()
        directionsRenderer.setMap map

    $edit = $('#edit')
    $versatile = $('#versatile')
    $routeSearchFrame = $('#route-search-frame')
    openRouteForm = () ->
        setLocalExpressionInto 'edit', 'Cancel'
        setLocalExpressionInto 'versatile', 'Route'
        $('#navi-header2').css 'display', 'none'
        $routeSearchFrame.css 'top', '0px'
        $destinationField.focus()

    $edit.on 'click', ->
        if $edit.text().replace(/^\s*|\s*$/, '') is getLocalizedString 'Edit'
            openRouteForm()
        else
            setLocalExpressionInto 'edit', 'Edit'
            setLocalExpressionInto 'versatile', 'Start'
            $('#navi-header2').css 'display', 'block' if navigate.leg? and navigate.step?
            $routeSearchFrame.css 'top', ''

    $('#edit2').on 'click', -> $edit.trigger 'click'

    $('#switch').on 'click', ->
        tmp = $destinationField.val()
        updateField $destinationField, $originField.val()
        updateField $originField, tmp
        saveOtherStatus()

    $('#origin, #destination').on 'submit', -> false
    $originField.on 'change', saveOtherStatus
    $destinationField.on 'change', saveOtherStatus

    $travelMode = $('#travel-mode')
    $travelMode.children().on 'click', ->
        $this = $(this)
        return if $this.hasClass 'btn-primary'
        $travelMode.children().removeClass 'btn-primary'
        $this.addClass 'btn-primary'
        setRouteMap()

    $versatile.on 'click', ->
        switch $versatile.text().replace(/^\s*|\s*$/, '')
            when getLocalizedString 'Route'
                setLocalExpressionInto 'edit', 'Edit'
                setLocalExpressionInto 'versatile', 'Start'
                $routeSearchFrame.css 'top', ''
                searchDirections false
            when getLocalizedString 'Start'
                navigate 'start'

    $('#cursor-left').on 'click', -> navigate 'previous'
    $('#cursor-right').on 'click', -> navigate 'next'

    backToMap = ->
        $map.css 'top', ''
        $map.css 'bottom', ''
        $('#directions-panel').css 'top', ''
        $('#directions-panel').css 'bottom', ''
        $option.removeClass 'btn-primary'

    $option = $('#option')
    $option.on 'click', ->
        $('#option-page').css 'display', 'block'
        if $option.hasClass 'btn-primary'
            backToMap()
        else
            $map.css 'top', $('#search-header .toolbar').outerHeight(true) - $('#option-page').outerHeight(true) + 'px'
            $map.css 'bottom', $('#footer').outerHeight(true) + $('#option-page').outerHeight(true) + 'px'
            $('#directions-panel').css 'top', $('#directions-header').outerHeight(true) - $('#option-page').outerHeight(true) + 'px'
            $('#directions-panel').css 'bottom', $('#footer').outerHeight(true) + $('#option-page').outerHeight(true) + 'px'
            $option.addClass 'btn-primary'

    $mapType = $('#map-type')
    $mapType.children().on 'click', ->
        $this = $(this)
        if $this.hasClass 'btn-primary'
            kmlLayer?.setMap null
            return
        $mapType.children().removeClass 'btn-primary'
        $this.addClass 'btn-primary'
        if $this.attr('id') is 'panel'
            $('#directions-window').css 'display', 'block'
        else
            map.setMapTypeId getMapType()
            $('#directions-window').css 'display', 'none'
            updateMessage() # in order to let message correspond to current route.
        backToMap()

    $traffic = $('#traffic')
    $traffic.on 'click', ->
        if $traffic.text() is getLocalizedString 'Show Traffic'
            trafficLayer.setMap map
            setLocalExpressionInto 'traffic', 'Hide Traffic'
        else
            trafficLayer.setMap null
            setLocalExpressionInto 'traffic', 'Show Traffic'
        backToMap()

    $panoramio = $('#panoramio')
    $panoramio.on 'click', ->
        if $panoramio.text() is getLocalizedString 'Show Panoramio'
            panoramioLayer.setMap map
            setLocalExpressionInto 'panoramio', 'Hide Panoramio'
        else
            panoramioLayer.setMap null
            setLocalExpressionInto 'panoramio', 'Show Panoramio'
        backToMap()


    $('#replace-pin').on 'click', ->
        droppedPlace.marker.setPosition map.getCenter()
        droppedPlace.marker.setVisible true
        backToMap()

    $('#print').on 'click', ->
        setTimeout window.print, 0
        backToMap()

    infoPage2Map = ->
        $('body').animate {scrollLeft: 0}, 300
        scrollLeft = false

    $('#button-map').on 'click', infoPage2Map

    $bookmarkPage = $('#bookmark-page')
    $('.btn-bookmark').on 'click', ->
        mapFSM.bookmarkClicked()
        ancestor = $(this).parent()
        ancestor = ancestor.parent() while ancestor.size() > 0 and ancestor[0].nodeName isnt 'FORM'
        bookmarkContext = ancestor.attr 'id'
        generateBookmarkList()
        $bookmarkPage.css 'bottom', '0'

    $('#bookmark-done').on 'click', ->
        $bookmarkPage.css 'bottom', '-100%'

    $('#pin-list').on 'click', 'td', ->
        name = $(this).data('object-name')
        return unless name? and name isnt ''
        if /history/.test name # history list
            item = eval(name)
            switch item.type
                when 'search'
                    updateField $addressField, item.address
                    $search.trigger 'click'
                    searchAddress true
                when 'route'
                    updateField $originField, item.origin
                    updateField $destinationField, item.destination
                    $route.trigger 'click'
                    searchDirections true
        else # bookmark list
            place = eval(name)
            switch bookmarkContext
                when 'address'
                    map.getStreetView().setVisible(false)
                    if place is currentPlace
                        mapFSM.setState(MapState.TRACE_POSITION)
                    else
                        mapFSM.setState(MapState.NORMAL)
                        updateField $addressField, place.address if place isnt droppedPlace
                        place.marker.setVisible true
                        map.setCenter place.marker.getPosition()
                        placeContext = place
                        place.showInfoWindow()
                when 'origin'
                    updateField $originField, if place is currentPlace
                            latLng = place.marker.getPosition()
                            "#{latLng.lat()}, #{latLng.lng()}"
                        else
                            place.address
                when 'destination'
                    updateField $destinationField, if place is currentPlace
                            latLng = place.marker.getPosition()
                            "#{latLng.lat()}, #{latLng.lng()}"
                        else
                            place.address

        $bookmarkPage.css 'bottom', '-100%'

    $('#add-bookmark').on 'click', -> $('#add-bookmark-page').css 'top', '0'

    $('#cancel-add-bookmark').on 'click', -> $('#add-bookmark-page').css 'top', ''

    $('#remove-pin').on 'click', ->
        if placeContext is droppedPlace
            droppedPlace.marker.setVisible false
        else
            index = bookmarks.indexOf placeContext
            bookmarks.splice index, 1
            saveOtherStatus()
            placeContext.marker.setMap null
        infoWindow.close()
        infoPage2Map()

    $('#bookmark-name').on 'submit', ->
        $('#bookmark-name input[name="bookmark-name"]').blur()
        $('#save-bookmark').trigger 'click'
        false

    $('#save-bookmark').on 'click', ->
        place = new Place new google.maps.Marker(
                map: map
                position: placeContext.marker.getPosition()
                title: $('#bookmark-name input[name="bookmark-name"]').val()
            ), $('#info-address').text() 
        bookmarks.push place
        saveOtherStatus()
        place.showInfoWindow()
        $('#add-bookmark-page').css 'top', ''
        infoPage2Map()


    $('#nav-bookmark button').on 'click', ->
        $this = $(this)
        $('#nav-bookmark button').removeClass 'btn-primary'
        $this.addClass 'btn-primary'
        switch $this.attr 'id'
            when 'bookmark'
                setLocalExpressionInto 'bookmark-message', 'Choose a bookmark to view on the map'
                setLocalExpressionInto 'bookmark-edit', 'Edit'
                $('#bookmark-edit').addClass('disabled')
                generateBookmarkList()
            when 'history'
                setLocalExpressionInto 'bookmark-message', 'Choose a recent search'
                setLocalExpressionInto 'bookmark-edit', 'Clear'
                $('#bookmark-edit').removeClass('disabled')
                generateHistoryList()

    $('#bookmark-edit').on 'click', ->
        switch $(this).text()
            when getLocalizedString 'Clear'
                if confirm getLocalizedString 'Clear All Recents'
                    history = []
                    generateHistoryList()

    $('#to-here').on 'click', ->
        updateField $destinationField, placeContext.address
        $route.trigger 'click'
        infoPage2Map()
        openRouteForm()

    $('#from-here').on 'click', ->
        updateField $originField, placeContext.address
        $route.trigger 'click'
        infoPage2Map()
        openRouteForm()

    $map.on 'click', (event) ->
        event.stopPropagation()
        if map.getStreetView().getVisible()
            map.getStreetView().setVisible false
            map.setOptions streetViewControl: false
            $('#map-page').removeClass 'streetview'
            google.maps.event.trigger map, 'resize'
            placeContext.showInfoWindow()
            map.setCenter centerBeforeSV

# auxiliary functions for initializDOM
restoreStatus = ->
    if localStorage['maps-other-status']?
        otherStatus = JSON.parse localStorage['maps-other-status']
        if otherStatus.address? and otherStatus.address isnt ''
            updateField $addressField, otherStatus.address
        if otherStatus.origin? and otherStatus.origin isnt ''
            updateField $originField, otherStatus.origin
        if otherStatus.destination? and otherStatus.destination isnt ''
            updateField $destinationField, otherStatus.destination
        for e in otherStatus.bookmarks ? []
            bookmarks.push new Place new google.maps.Marker(
                    map: map
                    position: new google.maps.LatLng e.lat, e.lng
                    title: e.title
                    visible: false
                ), e.address
        history = otherStatus.history ? []


# export

window.app =
    tracer: tracer
    initializeDOM: initializeDOM
    initializeGoogleMaps: initializeGoogleMaps
    saveMapStatus: saveMapStatus
    saveOtherStatus: saveOtherStatus
