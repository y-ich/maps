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

pulsatingMarker = null # is a pin of current position
naviMarker = null # is a pin navigating a route.
infoWindow = null # general purpose singlton of InfoWindow

droppedBookmark = null # combination of dropped marker and address information
searchBookmark = null # search result
currentBookmark = null # context bookmark

# jQuery instances
$map = null
$gps = null
$addressField = null
$originField = null
$destinationField = null
$pinList = null

# layout parameter
pinRowHeight = null

# state variables
mapFSM = null
bookmarkContext = null
bookmarks = [] # an array of Bookmark instances
history = [] # an array of Object instances. two formats. { type: 'search', address: }, { type: 'route', origin: ,destination: }
maxHistory = 20 # max number of history
isHold = true # hold detection of touch. default is true for desktop

#
# classes
#

# custom InfoWindow
class MobileInfoWindow extends google.maps.OverlayView
    constructor: (options) -> @setOptions options
    close: -> @setMap null
    getContent: -> @content
    getPosition: -> @position
    getZIndex: -> @zIndex
    open: (map, @anchor) ->
        if anchor?
            @setPosition @anchor.getPosition()
            icon = @anchor.getIcon()
            if icon?
                markerSize = icon.size
                markerAnchor = icon.anchor ? new google.maps.Point Math.floor(markerSize.width / 2), markerSize.height
            else
                markerSize = new google.maps.Size DEFAULT_ICON_SIZE, DEFAULT_ICON_SIZE            
                markerAnchor = new google.maps.Point DEFAULT_ICON_SIZE/2, DEFAULT_ICON_SIZE
            @pixelOffset = new google.maps.Size Math.floor(markerSize.width / 2) - markerAnchor.x, - markerAnchor.y, 'px', 'px'            
        @setMap map
        
    setContent: (@content) ->
        unless @element?
            @element = document.createElement 'div'
            @element.style['max-width'] = @maxWidth + 'px' if @maxWidth
            @element.className = 'info-window'
        if typeof @content is 'string'
            @element.innerHTML = @content
        else
            @element.appendChild @content
        google.maps.event.trigger this, 'content_changed'
        
    setOptions: (options) ->
        @maxWidth = options.maxWidth ? null
        @setContent options.content ? ''
        @disableAutoPan = options.disableAutoPan ? null
        @pixelOffset = options.pixelOffset ? google.maps.Size 0, 0, 'px', 'px'
        @setPosition options.position ? null
        @setZIndex options.zIndex ? 0
        
    setPosition: (@position) ->
        google.maps.event.trigger this, 'position_changed'
        
    setZIndex: (@zIndex) ->
        @element.style['z-index'] = @zIndex.toString()
        google.maps.event.trigger this, 'zindex_changed'

    # overlayview
    onAdd: ->
        @getPanes().floatPane.appendChild @element
        @listeners = []
        google.maps.event.trigger this, 'domready'

    draw: ->
        xy = @getProjection().fromLatLngToDivPixel @getPosition()
        @element.style.left = xy.x + @pixelOffset.width - @element.offsetWidth / 2 + 'px'
        @element.style.top = xy.y + @pixelOffset.height - @element.offsetHeight + 'px'

    onRemove: ->
        @listeners.forEach (e) -> google.maps.event.removeListener e
        @element.parentNode.removeChild @element
        @element = null

# manages id for navigator.geolocation
class WatchPosition
    start: (dummy) ->
        @id = navigator.geolocation.watchPosition.apply navigator.geolocation, Array.prototype.slice.call(arguments)
        @

    stop: ->
        navigator.geolocation.clearWatch @id unless @id
        @id = null
        @

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
    map.setCenter pulsatingMarker.getPosition()
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


# bookmark
class Bookmark
    constructor: (@marker, @address) ->
        google.maps.event.addListener @marker, 'click', (event) =>
            currentBookmark = @
            @showInfoWindow()

    setInfoWindow: ->
        makeInfoMessage = (title, message) ->
            """
            <table id="info-window"><tr>
                <td><button id="street-view" class="btn btn-mini"><i class="icon-user icon-white"></i></button></td>
                <td style="white-space: nowrap;"><div style="max-width:160px;overflow:hidden;">#{title}<br><span id="dropped-message" style="font-size:10px">#{message}</span></div></td>
                <td><button id="button-info" class="btn btn-mini btn-light"><i class="icon-chevron-right icon-white"></i></button></td>
            </tr></table>
            """
        infoWindow.setContent makeInfoMessage @marker.getTitle(), @address        

    showInfoWindow: ->
        @setInfoWindow()
        infoWindow.open map, @marker
        
    toObject: () ->
        pos = @marker.getPosition()
        {
            lat: pos.lat()
            lng: pos.lng()
            title: @marker.getTitle()
            address: @address
        }

#
# functions 
#


# localize function
window.getRouteIndexMessage = window.getRouteIndexMessage ? (index, total) ->
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
    "#{ordinal(index + 1)} of #{total} Suggested Routes"
    
getLocalizedString = (key) ->
    if localizedStrings? then localizedStrings[key] ? key else key

setLocalExpressionInto = (id, english) ->
    document.getElementById(id).lastChild.data = getLocalizedString english

localize = ->        
    idWordPairs = 
        'replace-pin' : 'Replace Pin'
        'print' : 'Print'
        'traffic' : 'Show Traffic'
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

sum = (array) ->
    array.reduce (a, b) -> a + b
    
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
getTravelMode = -> google.maps.TravelMode[$('#travel-mode').children('.btn-primary').attr('id').toUpperCase()]

# returns current map type on display
getMapType = -> google.maps.MapTypeId[$('#map-type').children('.btn-primary').attr('id').toUpperCase()]


# search and display a place
searchAddress = (fromHistory) ->
    address = $addressField.val()
    return unless address? and address isnt ''
    infoWindow.close()
    searchBookmark.marker.setVisible false
    if not fromHistory
        history.unshift
            type: 'search'
            address: address
    geocoder.geocode { address : address }, (result, status) ->
        if status is google.maps.GeocoderStatus.OK
            mapFSM.setState MapState.NORMAL
            map.setCenter result[0].geometry.location
            searchBookmark.address = result[0].formatted_address
            searchBookmark.marker.setPosition result[0].geometry.location
            searchBookmark.marker.setTitle address
            searchBookmark.marker.setVisible true
            searchBookmark.marker.setAnimation google.maps.Animation.DROP
            currentBookmark = searchBookmark
        else
            alert status

# invokes to search directions and displays a result.
searchDirections = (fromHistory = false) ->
    origin = $originField.val()
    destination = $destinationField.val()
    return unless origin? and origin isnt '' and destination? and destination isnt ''

    if not fromHistory
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
            switch status
                when google.maps.DirectionsStatus.OK
                    directionsRenderer.setMap map
                    directionsRenderer.setDirections result
                    index = directionsRenderer.getRouteIndex()
                    message += getRouteIndexMessage(index, result.routes.length) + '<br>' if result.routes.length > 1
                    distance = mapSum result.routes[index].legs, (e) -> e.distance.value
                    duration = mapSum result.routes[index].legs, (e) -> e.duration.value
                    summary = "#{secondToString duration} - #{meterToString distance} - #{result.routes[index].summary}"
                    if summary.length > innerWidth / parseInt($message.css('font-size')) # assuming the unit is px.
                        summary = "#{result.routes[index].summary}<br>#{secondToString duration} - #{meterToString distance}"
                    message += summary
                    $('#message').html message
                when google.maps.DirectionsStatus.ZERO_RESULTS
                    directionsRenderer.setMap null
                    mode = $('#travel-mode').children('.btn-primary').attr('id')
                    mode = mode[0].toUpperCase() + mode.substr 1
                    $('#message').html getLocalizedString(mode + ' directions could not be found between these locations')
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
    $('#message').html step.instructions

navigate.leg = null
navigate.step = null


# DOM treat

updateField = ($field, str) ->
    $field.val(str)
          .siblings('.btn-bookmark').css 'display', if str is '' then 'block' else 'none'

# prepare page of bookmark information
setInfoPage = (bookmark, dropped) ->
    console.log bookmark.marker.getIcon()
    $('#info-marker img:first-child').attr 'src', bookmark.marker.getIcon()?.url ? 'http://maps.google.co.jp/mapfiles/ms/icons/red-dot.png'
    title = bookmark.marker.getTitle()
    position = bookmark.marker.getPosition()
    $('#info-name').text title
    $('#bookmark-name input[name="bookmark-name"]').val if dropped then bookmark.address else title
    $('#info-address').text bookmark.address
    # $('#delete-pin').css 'display', if dropped then 'block' else 'none'
    $('#send-place').attr 'href', "mailto:?subject=#{title}&body=<a href=\"https://maps.google.co.jp/maps?q=#{position.lat()},#{position.lng()}\">#{title}</a>"

generateBookmarkList = ->
    list = "<tr><td data-object-name=\"pulsatingMarker\">#{getLocalizedString 'Current Location'}</td></tr>"
    list += "<tr><td data-object-name=\"droppedBookmark\">#{getLocalizedString 'Dropped Pin'}</td></tr>" if droppedBookmark.marker.getVisible()
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

#
# handlers
#

getPanoramaHandler = (data, status) ->
    switch status
        when google.maps.StreetViewStatus.OK
            sv = map.getStreetView()
            sv.setPosition data.location.latLng
            sv.setPov
                heading: map.getHeading() ? 0
                pitch: 0
                zoom: 1
            sv.setVisible true
        when google.maps.StreetViewStatus.ZERO_RESULTS
            alert getLocalizedString 'There are no street views near here.'
        else
            alert getLocaliedString 'Sorry, an error occurred.'

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
    directionsRenderer = new google.maps.DirectionsRenderer()
    directionsRenderer.setMap map
    google.maps.event.addListener directionsRenderer, 'directions_changed', ->
        navigate.leg = null
        navigate.step = null
        $('#navi-header2').css 'display', 'none'
        naviMarker.setVisible false

    droppedBookmark = new Bookmark new google.maps.Marker(
            animation: google.maps.Animation.DROP
            map: map
            icon: new google.maps.MarkerImage(PURPLE_DOT_IMAGE)
            shadow: new google.maps.MarkerImage(MSMARKER_SHADOW, null, null, new google.maps.Point(DEFAULT_ICON_SIZE/2, DEFAULT_ICON_SIZE))
            position: mapOptions.center
            title: getLocalizedString 'Dropped Pin'
            visible: false
        ), ''

    searchBookmark = new Bookmark new google.maps.Marker(
            animation: google.maps.Animation.DROP
            map: map
            position: mapOptions.center
            visible: false
        ), ''
    
    infoWindow = new MobileInfoWindow
        maxWidth: Math.floor innerWidth*0.9

    google.maps.event.addListener infoWindow, 'domready', ->
        $('#street-view').on 'click' , (event) ->
            new google.maps.StreetViewService().getPanoramaByLocation currentBookmark.marker.getPosition(), 49, getPanoramaHandler

        $('#button-info').on 'click', (event) ->
            setInfoPage(currentBookmark, currentBookmark is droppedBookmark)
            $('#container').css 'right', '100%'

        
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
            return if (position.left <= xy.x <= position.left + $infoWindow.width()) and (position.top <= xy.y <= position.top + $infoWindow.height())
                
        infoWindow.close()
        droppedBookmark.address = ''
        droppedBookmark.marker.setVisible true
        droppedBookmark.marker.setPosition event.latLng
        droppedBookmark.marker.setAnimation google.maps.Animation.DROP
        currentBookmark = droppedBookmark
        geocoder.geocode {latLng : event.latLng }, (result, status) ->
            droppedBookmark.address = if status is google.maps.GeocoderStatus.OK
                    result[0].formatted_address.replace(/日本, /, '')
                else
                    getLocalizedString 'No information'
            droppedBookmark.setInfoWindow()

    google.maps.event.addListener droppedBookmark.marker, 'animation_changed', ->
        droppedBookmark.showInfoWindow() if not this.getAnimation()? # animation property becomes undefined after animation ends

    google.maps.event.addListener searchBookmark.marker, 'animation_changed', ->
        searchBookmark.showInfoWindow() if not this.getAnimation()? # animation property becomes undefined after animation ends

    google.maps.event.addListener map, 'dragstart', -> mapFSM.setState MapState.NORMAL
    # This is a workaround for web app on home screen. There is no onpagehide event.
    google.maps.event.addListener map, 'center_changed', saveMapStatus
    google.maps.event.addListener map, 'zoom_changed', saveMapStatus



initializeDOM = ->
    # initializes global variables
    $map = $('#map')
    $gps = $('#gps')
    $addressField = $('#address input[name="address"]')
    $originField = $('#origin input[name="origin"]')
    $destinationField = $('#destination input[name="destination"]')
    $pinList = $('#pin-list')
    pinRowHeight = $('#pin-list tr').height()


    # prevents default page scroll, but scroll bookmark/history list.
    document.addEventListener 'touchmove', (event) ->
        event.preventDefault()
    $('#pin-list-frame, #info').on 'touchmove', (event) ->
        event.stopPropagation()

    # restores from localStorage
    if localStorage['maps-other-status']?
        otherStatus = JSON.parse localStorage['maps-other-status']
        if otherStatus.origin? and otherStatus.origin isnt ''
            updateField $originField, otherStatus.origin
        if otherStatus.destination? and otherStatus.destination isnt ''
            updateField $destinationField, otherStatus.destination
        for e in otherStatus.bookmarks ? []
            bookmarks.push new Bookmark new google.maps.Marker(
                    map: map
                    position: new google.maps.LatLng e.lat, e.lng
                    title: e.title
                ), e.address
        history = otherStatus.history ? []

    #localization
    localize()
    
    # layouts dynamically
    $('#option-page').css 'bottom', $('#footer').outerHeight(true)
# disabled heading trace
#    # makes map large square for rotation of heading
#    squareSize = Math.floor(Math.sqrt(Math.pow(innerWidth, 2) + Math.pow(innerHeight, 2)))
#    $map.width(squareSize)
#        .height(squareSize)
#        .css('margin', - squareSize / 2 + 'px')
    # fits map between header and footer
    visibleSearchHeaderHeight = $('#search-header').outerHeight(true) + parseInt $('#search-header').css 'top'
    $map.css 'top', visibleSearchHeaderHeight + 'px'
    $map.height innerHeight - visibleSearchHeaderHeight - $('#footer').outerHeight(true)
    # fits list frame between header and footer. should be rewritten.
    $('#pin-list-frame').css 'height', innerHeight - mapSum($('#bookmark-page > div:not(#pin-list-frame)').toArray(), (e) -> $(e).outerHeight(true)) + 'px'

    #
    # event handlers
    #

    $map.on 'touchstart', ->
        isHold = false
        setTimeout (-> isHold = true), 800
        
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
        searchBookmark.marker.setVisible false
        infoWindow.setVisible false if currentBookmark is searchBookmark
        

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

    $originField.on 'change', saveOtherStatus
    $destinationField.on 'change', saveOtherStatus

    $travelMode = $('#travel-mode')
    $travelMode.children(':not(#transit)').on 'click', -> # disabled transit
        $this = $(this)
        return if $this.hasClass 'btn-primary'
        $travelMode.children().removeClass 'btn-primary'
        $this.addClass 'btn-primary'
        searchDirections false
        
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
        $option.removeClass 'btn-primary'
        
    $option = $('#option')
    $option.on 'click', ->
        $('#option-page').css 'display', 'block' # option-page is not visible in order to let startup clear.

        if $option.hasClass 'btn-primary'
            backToMap()
        else
            $map.css 'top', $('#search-header .toolbar').outerHeight() - $('#option-page').outerHeight(true) + 'px'
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
        if $traffic.text() is getLocalizedString 'Show Traffic'
            trafficLayer.setMap map
            setLocalExpressionInto 'traffic', 'Hide Traffic'
        else
            trafficLayer.setMap null
            setLocalExpressionInto 'traffic', 'Show Traffic'
        backToMap()

    $('#replace-pin').on 'click', ->
        droppedBookmark.marker.setPosition map.getCenter()
        droppedBookmark.marker.setVisible true
        backToMap()

    $('#print').on 'click', ->
        setTimeout window.print, 0
        backToMap()
        
    $('#button-map').on 'click', ->
        $('#container').css 'right', ''
        
    $bookmarkPage = $('#bookmark-page')    
    $('.btn-bookmark').on 'click', ->
        mapFSM.bookmarkClicked()
        bookmarkContext = $(this).parent().attr 'id'
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
            bookmarkOrMarker = eval(name)
            switch bookmarkContext
                when 'address'
                    map.getStreetView().setVisible(false)
                    if name is 'pulsatingMarker'
                        mapFSM.setState(MapState.TRACE_POSITION)
                    else
                        mapFSM.setState(MapState.NORMAL)
                        updateField $addressField, bookmarkOrMarker.address if bookmarkOrMarker isnt droppedBookmark
                        map.setCenter bookmarkOrMarker.marker.getPosition()
                        currentBookmark = bookmarkOrMarker
                        bookmarkOrMarker.showInfoWindow()
                when 'origin'
                    updateField $originField, if name is 'pulsatingMarker'
                            latLng = bookmarkOrMarker.getPosition()
                            "#{latLng.lat()}, #{latLng.lng()}"
                        else
                            bookmarkOrMarker.address            
                when 'destination'
                    updateField $destinationField, if name is 'pulsatingMarker'
                            latLng = bookmarkOrMarker.getPosition()
                            "#{latLng.lat()}, #{latLng.lng()}"
                        else
                            bookmarkOrMarker.address            

        $bookmarkPage.css 'bottom', '-100%'

    $('#add-bookmark').on 'click', -> $('#add-bookmark-page').css 'top', '0'

    $('#cancel-add-bookmark').on 'click', -> $('#add-bookmark-page').css 'top', ''

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
        updateField $destinationField, currentBookmark.address
        $route.trigger 'click'
        $('#container').css 'right', ''
        openRouteForm()
        
    $('#from-here').on 'click', ->
        updateField $originField, currentBookmark.address
        $route.trigger 'click'
        $('#container').css 'right', ''
        openRouteForm()
            
    watchPosition = new WatchPosition().start traceHandler
        , (error) -> console.log error.message
        , { enableHighAccuracy: true, timeout: 30000 }

    window.onpagehide = ->
        watchPosition.stop()
        saveMapStatus()
        saveOtherStatus()

initializeDOM()
initializeGoogleMaps()

