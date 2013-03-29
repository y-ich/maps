# Google Maps Web App
# Copyright (C) 2012-2103 ICHIKAWA, Yuji (New 3 Rs) 

CLIENT_ID = '369757625302.apps.googleusercontent.com'
SCOPES = [
    'https://www.googleapis.com/auth/calendar'
]
MAP_STATUS = 'spacetime-map-status'

map = null
infoWindow = null
events = []
geocoder = null

handleClientLoad = ->
    window.setTimeout authorizeFunction(CLIENT_ID, SCOPES, true, handleAuthResult), 1

authorizeFunction = (client_id, scopes, immediate, callback) ->
    ->
        gapi.auth.authorize
                'client_id': client_id
                'scope': scopes
                'immediate': immediate
            , callback

handleAuthResult = (authResult) ->
    if authResult and not authResult.error
        console.log 'ok'
        gapi.client.load 'calendar', 'v3', ->
            $('#button-authorize').css 'display', 'none'
            $('#button-calendar').css 'display', ''
    else
        console.log 'ng'
        $('#button-authorize').text('Authorize this app')
                                         .attr('disabled', null)
                                         .addClass 'primary'

window.handleClientLoad = handleClientLoad


getLocalizedString = (key) ->
    if localizedStrings? then localizedStrings[key] ? key else key

setLocalExpressionInto = (id, english) ->
    el = document.getElementById id
    el.lastChild.data = getLocalizedString english if el?

localize = ->
    idWordPairs = []

    document.title = getLocalizedString 'Maps'
    # document.getElementById('search-input').placeholder = getLocalizedString 'Search or Address'
    setLocalExpressionInto key, value for key, value of idWordPairs

# saves current state into localStorage
# saves frequently changing state
saveMapStatus = () ->
    pos = map.getCenter()
    localStorage[MAP_STATUS] = JSON.stringify
        lat: pos.lat()
        lng: pos.lng()
        zoom: map.getZoom()

timeZone = (calendarId) ->
    
# is a class with a marker, responsible for InfoWindow.
class Place
    # constructs an instance from marker and address, gets address if missed, gets Street View info and sets event listener.
    constructor: (options, @content) ->
        @marker = new google.maps.Marker options
        google.maps.event.addListener @marker, 'click', @showInfoWindow

    # shows its InfoWindow.
    showInfoWindow: =>
        @_setInfoWindow()
        infoWindow.open @marker.getMap(), @marker

    _setInfoWindow: ->
        infoWindow.setContent @content


# is a class of Google Calendar Event.
# is capable to geocode the location of events and saves it as extendedProperties.private.geolocation.
# Event.geocodeCount should be reset to 0 when starting simultaneous geocode requests 
class Event
    @mark: 'A' # next alphabetic marker
    @geocodeCount: 0 # Google accepts only ten simultaneous geocode requests. So count them.
    @shadow:
        url: 'http://www.google.com/mapfiles/shadow50.png'
        anchor: new google.maps.Point(10, 34)

    constructor: (@calendarId, @resource) ->
        if @resource.location? and @resource.location isnt ''
            @icon =
                url: "http://www.google.com/mapfiles/marker#{Event.mark}.png"
            Event.mark = String.fromCharCode Event.mark.charCodeAt(0) + 1 if Event.mark isnt 'Z'
            @tryToSetPlace()

    latLng: ->
        if @resource.extendedProperties?.private?.geolocation?
            geolocation = JSON.parse @resource.extendedProperties.private.geolocation
            new google.maps.LatLng geolocation.lat, geolocation.lng
        else
            null

    geocode: (callback) -> # the argument of callback is the first arugment of geocode callback.
        if Event.geocodeCount > 10
            console.log 'too many geocoding requests'
            return false

        geocoder.geocode { address: @resource.location }, (results, status) =>
            switch status
                when google.maps.GeocoderStatus.OK
                    if results.length is 1
                        @_updateGeolocation results[0].geometry.location.lat(), results[0].geometry.location.lng(), results[0].formatted_address
                    else
                        console.log 'several candicates', results
                    callback results
                when google.maps.GeocoderStatus.ZERO_RESULTS
                    setTimeout (-> alert "Where is #{@resource.location}?"), 0
                else
                    console.error status
        Event.geocodeCount += 1

    setPlace: ->
        return null unless @resource.location? and @resource.location isnt ''
        latLng = @latLng()
        return null unless latLng
        @place = new Place
                map: map
                position: latLng
                icon: @icon ? null
                shadow: if @icon? then Event.shadow else null
                title: @resource.location
            , """
            <h5>#{@resource.summary}</h5>
            <dl class="dl-horizontal">
                <dt>Location</dt>
                <dd>#{@resource.location ? ''}</dd>
                <dt>Start</dt>
                <dd>#{(@resource.start.date ? @resource.start.dateTime & '') + (@resource.start.timeZone ? timeZone @calendarId)}</dd>
                <dt>End</dt>
                <dd>#{(@resource.end.date ? @resource.end.dateTime & '') + (@resource.start.timeZone ? timeZone @calendarId)}</dd>
                <dt>Description</dt>
                <dd>#{@resource.description ? ''}</dd>
            </dl>
            """

    tryToSetPlace: ->
        unless @setPlace()
            @geocode (results) =>
                unless @setPlace()
                    @candidates = []
                    for e in results
                        @candidates.push new Place
                                map: map
                                position: e.geometry.location
                                icon: @icon ? null
                                shadow: if @icon? then Event.shadow else null
                                title: @resource.location + '?'
                                optimized: false
                            , """
                            <h5>#{@resource.summary}</h5>
                            <dl class="dl-horizontal">
                                <dt>Location</dt>
                                <dd>#{@resource.location ? ''}</dd>
                                <dt>Here is</dt>
                                <dd>#{e.formatted_address}</dd>
                                <dt>Start</dt>
                                <dd>#{(@resource.start.date ? @resource.start.dateTime & '') + (@resource.start.timeZone ? timeZone @calendarId)}</dd>
                                <dt>End</dt>
                                <dd>#{(@resource.end.date ? @resource.end.dateTime & '') + (@resource.start.timeZone ? timeZone @calendarId)}</dd>
                                <dt>Description</dt>
                                <dd>#{@resource.description ? ''}</dd>
                            </dl>
                            """
                    setTimeout (=>
                        $("#map img[src=\"#{@icon.url}\"]").addClass 'candidate'
                    ), 500

    _updateGeolocation: (lat, lng, address) ->
        @resource.extendedProperties ?= {}
        @resource.extendedProperties.private ?= {}
        @resource.extendedProperties.private.geolocation = JSON.stringify
            lat: lat
            lng: lng
            address: address
        gapi.client.calendar.events.update(
            calendarId: @calendarId
            eventId: @resource.id
            resource: @resource
        ).execute (resp) ->
            if resp.error?
                console.error 'gapi.client.calendar.events.update', resp

initializeDOM = ->
    localize()
    $('#container').css 'display', ''
    $('#button-authorize').on 'click', authorizeFunction CLIENT_ID, SCOPES, false, handleAuthResult

    $calendarList = $('#calendar-list')
    $('#modal-calendar').on 'show', (event) ->
        req = gapi.client.calendar.calendarList.list()
        req.execute (resp) ->
            if resp.error?
                console.error resp
            else
                $calendarList.html ("<option value=\"#{e.id}\">#{e.summary}</option>" for e in resp.items).join('')

    $('#button-show').on 'click', (event) ->
        infoWindow.setMap null
        for e in events
            e.marker?.setMap null
        events = []
        Event.count = 0
        id = $calendarList.children('option:selected').attr 'value'
        options =
            calendarId: id
        options.timeMin = $('#form-calendar [name="start-date"]')[0].value + 'T00:00:00Z' unless $('#form-calendar [name="start-date"]')[0].value is ''
        options.timeMax = $('#form-calendar [name="end-date"]')[0].value + 'T00:00:00Z' unless $('#form-calendar [name="end-date"]')[0].value is ''
        req = gapi.client.calendar.events.list options
        req.execute (resp) ->
            if resp.error?
                console.error resp
            else
                resp.items.sort (x, y) -> new Date(x.start.dateTime ? x.start.date + 'T00:00:00Z').getTime() - new Date(y.start.dateTime ? y.start.date + 'T00:00:00Z').getTime()
                Event.geocodeCount = 0
                for e in resp.items
                    event = new Event id, e
                    events.push event

initializeGoogleMaps = ->
    mapOptions =
        mapTypeId: google.maps.MapTypeId.ROADMAP
        disableDefaultUI: true
        streetView: new google.maps.StreetViewPanorama(document.getElementById('streetview'),
            panControl: false,
            zoomControl: false,
            visible: false
        )

    google.maps.event.addListener mapOptions.streetView, 'position_changed', ->
        map.setCenter this.getPosition()

    # restore map status
    if localStorage[MAP_STATUS]?
        mapStatus = JSON.parse localStorage[MAP_STATUS]
        mapOptions.center = new google.maps.LatLng mapStatus.lat, mapStatus.lng
        mapOptions.zoom = mapStatus.zoom
    else
        mapOptions.center = new google.maps.LatLng 35.660389, 139.729225
        mapOptions.zoom = 14

    map = new google.maps.Map document.getElementById('map'), mapOptions
    map.setTilt 45

    infoWindow = new MobileInfoWindow
        maxWidth: Math.floor innerWidth * 0.9

    google.maps.event.addListener map, 'mousedown', (event) ->
        $infoWindow = $('.info-window')
        if $infoWindow.length > 0
            xy = infoWindow.getProjection().fromLatLngToDivPixel event.latLng
            position = $infoWindow.position()
            return if (position.left <= xy.x <= position.left + $infoWindow.outerWidth(true)) and (position.top <= xy.y <= position.top + $infoWindow.outerHeight(true))

        infoWindow.close()

    geocoder = new google.maps.Geocoder()

# export

window.app =
    initialize: ->
        initializeGoogleMaps()
        initializeDOM()
    saveMapStatus: saveMapStatus
