# Google Maps Web App
# Copyright (C) ICHIKAWA, Yuji (New 3 Rs) 2012

#
# global variables
#

# constants
PURPLE_DOT_IMAGE = 'http://maps.google.co.jp/mapfiles/ms/icons/purple-dot.png'
RED_DOT_IMAGE = 'http://maps.google.co.jp/mapfiles/ms/icons/red-dot.png'
MSMARKER_SHADOW = 'http://maps.google.co.jp/mapfiles/ms/icons/msmarker.shadow.png'
DEFAULT_ICON_SIZE = 32

# Google Maps services
map = null
geocoder = null
directionsRenderer = null
trafficLayer = null
panoramioLayer = null

currentPlace = null # is a pin of current position
naviMarker = null # is a pin navigating a route.
infoWindow = null # general purpose singlton of InfoWindow

droppedPlace = null # combination of dropped marker and address information
searchPlace = null # search result
placeContext = null # context place

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
    id: null
    start: ->
        @id = navigator.geolocation.watchPosition @success
            , ((error) -> console.log error.message + '(' + error.code + ')')
            ,
                enableHighAccuracy: true
                timeout: 30000
    stop: ->
        navigator.geolocation.clearWatch @id unless @id
        @id = null
    success: (position) ->
        latLng = new google.maps.LatLng position.coords.latitude,position.coords.longitude
        currentPlace.marker.setVisible true
        currentPlace.marker.setPosition latLng
        currentPlace.marker.setRadius position.coords.accuracy
        currentPlace.address = '' # because current address may become old.
        map.setCenter latLng unless mapFSM.is MapState.NORMAL
        # if mapFSM.is MapState.TRACE_HEADING and position.coords.heading?
        #     transform = $map.css('-webkit-transform')
        #     if /rotate(-?[\d.]+deg)/.test(transform)
        #         transform = transform.replace(/rotate(-?[\d.]+deg)/, "rotate(#{-position.coords.heading}deg)")
        #     else
        #         transform = transform + " rotate(#{-position.coords.heading}deg)"
        #     $map.css('-webkit-transform', transform)


# abstract class for map's trace state
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
    bookmarkClicked: -> @

MapState.NORMAL.update = ->
    $gps.removeClass('btn-light')
    # disabled trace heading
    # $map.css '-webkit-transform', $map.css('-webkit-transform').replace(/\s*rotate(-?[\d.]+deg)/, '')
    # need to restore icon if implementing TRACE_HEADING
    @
MapState.NORMAL.gpsClicked = -> MapState.TRACE_POSITION

MapState.TRACE_POSITION.update = ->
    map.setCenter currentPlace.marker.getPosition() if currentPlace.marker.getVisible()
    $gps.addClass 'btn-light'
    @
MapState.TRACE_POSITION.gpsClicked = -> MapState.NORMAL # disabled TRACE_HEADING

MapState.TRACE_HEADING.update = ->
    # need to change icon
    @
MapState.TRACE_HEADING.gpsClicked = -> MapState.NORMAL
MapState.TRACE_HEADING.bookmarkClicked = -> MapState.TRACE_POSITION


# state machine for map
class MapFSM
    constructor: (@state) ->

    is: (state) -> @state is state

    setState: (state) ->
        return if @state is state
        @state = state
        @state.update()
# delegate
for name, method of MapState.prototype when typeof method is 'function'
    MapFSM.prototype[name] = ((name) ->
        -> this.setState this.state[name]())(name) # substantiation of name



# place
class Place
    @streetViewService: new google.maps.StreetViewService()
    @streetViewButtonWrapper: $('<div class="button-wrapper wrapper-left"></div>').on('click', ->
        if placeContext.svLatLng?
            $map.addClass 'streetview'
            sv = map.getStreetView()
            sv.setPosition placeContext.svLatLng
            sv.setPov
                heading: map.getHeading() ? 0
                pitch: 0
                zoom: 1
            sv.setVisible true)
    @infoButtonWrapper: $('<div class="button-wrapper wrapper-right"></div>').on('click', ->
            setInfoPage(placeContext, placeContext is droppedPlace)
            $('body').animate {scrollLeft: innerWidth}, 1000
        )

    constructor: (@marker, @address) ->
        google.maps.event.addListener @marker, 'click', (event) =>
            placeContext = @
            @showInfoWindow()

    setInfoWindow: ->
        $container = $('<div>')
        $container.html """
                        <table id="info-window"><tr>
                            <td>
                                <button id="street-view" class="btn btn-mini#{if @svLatLng? then ' btn-primary' else ''}">
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
        infoWindow.setContent $container.append(Place.streetViewButtonWrapper, Place.infoButtonWrapper)[0]
        

    showInfoWindow: ->
        @setInfoWindow()
        infoWindow.open map, @marker
        unless @svLatLng?
            Place.streetViewService.getPanoramaByLocation placeContext.marker.getPosition(), 49, (data, status) =>
                if status is google.maps.StreetViewStatus.OK
                    @svLatLng = data.location.latLng
                    $('#street-view').addClass 'btn-primary'
        
        unless @address? and @address isnt ''
            geocoder.geocode {latLng : @marker.getPosition() }, (result, status) =>
                @address = if status is google.maps.GeocoderStatus.OK
                        result[0].formatted_address.replace(/日本, /, '')
                    else
                        getLocalizedString 'No information'
                @setInfoWindow()
        
    toObject: () ->
        pos = @marker.getPosition()
        {
            lat: pos.lat()
            lng: pos.lng()
            title: @marker.getTitle()
            address: @address
        }


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
    switch n % 10
        when 1
            '1st'
        when 2
            '2nd'
        when 3
            '3rd'
        else
            n + 'th'

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
        'delete-pin' : 'Remove Pin'
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
    geocoder.geocode { address : address }, (result, status) ->
        if status is google.maps.GeocoderStatus.OK
            directionsRenderer.setMap null
            latLng = currentPlace.marker.getPosition()
            updateField $originField, "#{latLng.lat()}, #{latLng.lng()}"
            updateField $destinationField, result[0].formatted_address
            mapFSM.setState MapState.NORMAL
            map.setCenter result[0].geometry.location
            searchPlace.address = result[0].formatted_address
            searchPlace.marker.setPosition result[0].geometry.location
            searchPlace.marker.setTitle address
            searchPlace.marker.setVisible true
            searchPlace.marker.setAnimation google.maps.Animation.DROP
            placeContext = searchPlace
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
                when google.maps.DirectionsStatus.ZERO_RESULTS
                    directionsRenderer.setMap null
                    mode = $('#travel-mode').children('.btn-primary').attr('id')
                    mode = mode[0].toUpperCase() + mode.substr 1
                    $message.html getLocalizedString(mode + ' directions could not be found between these locations')
                    Alert getLocalizedString 'Directions Not Available\nDirections could not be found between these locations.'   
                else
                    directionsRenderer.setMap null
                    console.log status

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
    # $('#delete-pin').css 'display', if dropped then 'block' else 'none'
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
    mapOptions =
        mapTypeId: getMapType()
        disableDefaultUI: true

    # restore map status
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
    infoWindow = new MobileInfoWindow
        maxWidth: Math.floor innerWidth*0.9

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
            shadow: new google.maps.MarkerImage(MSMARKER_SHADOW, null, null, new google.maps.Point(DEFAULT_ICON_SIZE/2, DEFAULT_ICON_SIZE))
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

    google.maps.event.addListener map, 'click', (event) ->
        unless isHold
            infoWindow.close()
            return

        # The following code is a work around for iOS Safari. iOS Safari can not stop propagation of mouse event on the map.
        $infoWindow = $('.info-window')
        if $infoWindow.length > 0
            xy = infoWindow.getProjection().fromLatLngToDivPixel event.latLng
            position = $infoWindow.position()
            return if (position.left <= xy.x <= position.left + $infoWindow.outerWidth(true)) and (position.top <= xy.y <= position.top + $infoWindow.outerHeight(true))
                
        infoWindow.close()
        droppedPlace.address = ''
        droppedPlace.svLatLng = null
        droppedPlace.marker.setPosition event.latLng
        droppedPlace.marker.setVisible true
        droppedPlace.marker.setAnimation google.maps.Animation.DROP
        placeContext = droppedPlace

    google.maps.event.addListener droppedPlace.marker, 'animation_changed', ->
        droppedPlace.showInfoWindow() if not this.getAnimation()? # animation property becomes undefined after animation ends

    google.maps.event.addListener searchPlace.marker, 'animation_changed', ->
        searchPlace.showInfoWindow() if not this.getAnimation()? # animation property becomes undefined after animation ends

    google.maps.event.addListener map, 'dragstart', -> mapFSM.setState MapState.NORMAL
    # The followings are a workaround for web app on home screen. As there is no onpagehide event, saves statuses when updated.
    google.maps.event.addListener map, 'center_changed', saveMapStatus
    google.maps.event.addListener map, 'zoom_changed', saveMapStatus

    google.maps.event.addListener map.getStreetView(), 'visible_changed', ->
        unless @getVisible()
            $map.removeClass 'streetview'
            
    trafficLayer = new google.maps.TrafficLayer()

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


    # prevents default page scroll, but scroll bookmark/history list.
    document.addEventListener 'touchmove', (event) ->
        event.preventDefault()
    $('#pin-list-frame, #info, #directions-panel').on 'touchmove', (event) ->
        event.stopPropagation()

    # restores from localStorage
    if localStorage['maps-other-status']?
        otherStatus = JSON.parse localStorage['maps-other-status']
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

    #localization
    localize()
    

    $(document.body).css 'display', 'block'
    window.scrollTo 0, 0
    $('html, body').height innerHeight if /iPhone/.test(navigator.userAgent) and /Safari/.test(navigator.userAgent)
    
    #
    # event handlers
    #

    window.addEventListener 'orientationchange', ->
        document.body.scrollLeft = 0 unless /iPhone/.test(navigator.userAgent) and /Safari/.test(navigator.userAgent) # Rotation back to portait causes slight left slide of page. correct it. 
        # The above work around caused that address bar disappear to upper on iPhone.
        # I don't know any consistent work around, so gave up to correct slide on iPhone Safari.
 
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
            
    $('input').on 'blur', ->
        left = document.body.scrollLeft
        window.scrollTo left, 0 # I wanted to animate but, animation was flickery on iphone as left always reset to 0 during animation. 
        
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
        infoWindow.setVisible false if placeContext is searchPlace
        

    $naviHeader = $('#navi-header1')
    $search = $('#search')
    $search.on 'click', ->
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
    $mapType.children(':not(#panel)').on 'click', ->
        $this = $(this)
        return if $this.hasClass 'btn-primary'
        $mapType.children().removeClass 'btn-primary'
        $this.addClass 'btn-primary'
        map.setMapTypeId getMapType()
        $('#directions-window').css 'display', 'none'
        updateMessage() # in order to let message correspond to current route.
        backToMap()

    $('#panel').on 'click', ->
        $this = $(this)
        return if $this.hasClass 'btn-primary'
        $mapType.children().removeClass 'btn-primary'
        $this.addClass 'btn-primary'
        $('#directions-window').css 'display', 'block'
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
        
    $('#button-map').on 'click', -> $('body').animate {scrollLeft: 0}, 1000
        
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
    
    $(document).on 'click', '#pin-list td', ->
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
                            latLng = place.getPosition()
                            "#{latLng.lat()}, #{latLng.lng()}"
                        else
                            place.address            
                when 'destination'
                    updateField $destinationField, if place is currentPlace
                            latLng = place.getPosition()
                            "#{latLng.lat()}, #{latLng.lng()}"
                        else
                            place.address            

        $bookmarkPage.css 'bottom', '-100%'

    $('#add-bookmark').on 'click', -> $('#add-bookmark-page').css 'top', '0'

    $('#cancel-add-bookmark').on 'click', -> $('#add-bookmark-page').css 'top', ''

    $('#delete-pin').on 'click', ->
        if placeContext is droppedPlace
            droppedPlace.marker.setVisible false
        else
            index = bookmarks.indexOf placeContext
            bookmarks.splice index, 1
            saveOtherStatus()
            placeContext.marker.setMap null
        infoWindow.close()
        $('#container').css 'right', ''
        
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
        $('#container').css 'right', ''


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
        $('#container').css 'right', ''
        openRouteForm()
        
    $('#from-here').on 'click', ->
        updateField $originField, placeContext.address
        $route.trigger 'click'
        $('#container').css 'right', ''
        openRouteForm()

# export

window.app =
    tracer: tracer
    initializeDOM: initializeDOM
    initializeGoogleMaps: initializeGoogleMaps
    saveMapStatus: saveMapStatus
    saveOtherStatus: saveOtherStatus
