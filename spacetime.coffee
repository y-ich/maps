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

class Event
    @count: 0
    @shadow:
        url: 'http://www.google.com/mapfiles/shadow50.png'
        anchor: new google.maps.Point(10, 34)
    constructor: (@calendarId, @resource) ->
        if @resource.location? and @resource.location isnt '' and Event.count < 26
            console.log @resource.location, String.fromCharCode('A'.charCodeAt(0) + Event.count)
            @icon =
                url: "http://www.google.com/mapfiles/marker#{String.fromCharCode('A'.charCodeAt(0) + Event.count)}.png"
            Event.count += 1

    latLng: ->
        if match = @resource.location?.match /\((\d*\.\d*)\s*,\s*(\d*\.\d*)\)/
            new google.maps.LatLng parseFloat(match[1]), parseFloat(match[2])
        else
            null

    geocode: (callback) ->
        return if @latLng()
        geocoder.geocode { address: @resource.location }, (results, status) =>
            if status is google.maps.GeocoderStatus.OK
                if results.length is 1
                    @resource.location += results[0].geometry.location.toString()
                    req = gapi.client.calendar.events.update
                        calendarId: @calendarId
                        eventId: @resource.id
                        resource: @resource
                    req.execute (resp) ->
                        if resp.error?
                            console.log resp.error
                        else
                            console.log 'update succeed'
                    callback()
                else
                    console.log 'several candicates'
                    console.log results
            else
                console.error status

    setMarker: ->
        return unless @resource.location? and @resource.location isnt ''
        latLng = @latLng()
        options =
            map: map
            position: latLng
            icon: @icon ? null
            shadow: if @icon? then Event.shadow else null
            title: @resource.location.replace(/\(\d*\.\d*\s*,\s*\d*.\d*\)/, '')
        if latLng?
            @marker = new google.maps.Marker options
            google.maps.event.addListener @marker, 'click', @showInfoWindow
            return true
        else
            @geocode =>
                latLng = @latLng()
                if latLng?
                    options.position = latLng
                    @marker = new google.maps.Marker options
                    google.maps.event.addListener @marker, 'click', @showInfoWindow
            return null

    showInfoWindow: =>
        infoWindow.setOptions
            content: """
            <h5>#{@resource.summary}</h5>
            <dl class="dl-horizontal">
                <dt>Location</dt>
                <dd>#{@resource.location ? ''}</dd>
                <dt>Description</dt>
                <dd>#{@resource.description ? ''}</dd>
            </dl>
            """
        infoWindow.open map, @marker

initializeDOM = ->
    localize()
    $('#container').css 'display', ''
    $('#button-authorize').on 'click', authorizeFunction CLIENT_ID, SCOPES, false, handleAuthResult

    $calendarList = $('#calendar-list')
    $('#modal-calendar').on 'show', (event) ->
        req = gapi.client.calendar.calendarList.list()
        req.execute (resp) ->
            if resp.error?
                console.error resp.error
            else
                $calendarList.html ("<option value=\"#{e.id}\">#{e.summary}</option>" for e in resp.items).join('')

    $('#button-show').on 'click', (event) ->
        id = $calendarList.children('option:selected').attr 'value'
        options =
            calendarId: id
        options.timeMin = $('#form-calendar [name="start-date"]')[0].value + 'T00:00:00Z' unless $('#form-calendar [name="start-date"]')[0].value is ''
        options.timeMax = $('#form-calendar [name="end-date"]')[0].value + 'T00:00:00Z' unless $('#form-calendar [name="end-date"]')[0].value is ''
        req = gapi.client.calendar.events.list options
        req.execute (resp) ->
            if resp.error?
                console.log resp.error
            else
                console.log resp.items
                resp.items.sort (x, y) -> new Date(x.start.dateTime ? x.start.date + 'T00:00:00Z').getTime() - new Date(y.start.dateTime ? y.start.date + 'T00:00:00Z').getTime()
                for e in resp.items
                    event= new Event id, e
                    event.setMarker()
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
