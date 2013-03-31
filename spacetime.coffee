# Google Maps Web App
# Copyright (C) 2012-2103 ICHIKAWA, Yuji (New 3 Rs) 

CLIENT_ID = '369757625302.apps.googleusercontent.com'
SCOPES = [
    'https://www.googleapis.com/auth/calendar'
]
MAP_STATUS = 'spacetime-map-status'
# TIME_ZONE_HOST = 'http://localhost:9292'
TIME_ZONE_HOST = 'http://safari-park.herokuapp.com'

map = null
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


timeDifference = (offset) ->
    twoDigitsFormat = (n) -> if n < 10 then '0' + n else n.toString()
    offsetHours = Math.floor(offset / (60 * 60))
    offsetMinutes = Math.floor(offset / 60 - offsetHours * 60)
    (if offset >= 0 then '+' else '-') + twoDigitsFormat(offsetHours) + twoDigitsFormat(offsetMinutes)

# date is an instance of Date. offset is offset seconds including day-light-saving.
localTime = (date, offset) ->
    new Date(date.getTime() + offset * 1000).toISOString().replace /\..*Z/, timeDifference(offset) # ISOString is such as '2013-04-24T08:15:00.000Z'

# queries time zone
# date is an instance of Date. position is an instance of LatLng.
# argument of callback should have following properties.
# dstOffset: daylight-savings offset (sec)
# rawOffset: offset from UTC
# timeZoneId:
# timeZoneName:
getTimeZone = (date, position, callback) ->
    return false if getTimeZone.overQueryLimit
    location = "#{position.lat()},#{position.lng()}"
    timestamp = Math.floor(date.getTime() / 1000)
    $.getJSON "#{TIME_ZONE_HOST}/timezone/json?location=#{location}&timestamp=#{timestamp}&sensor=false&callback=?", (obj) ->
        switch obj.status
            when 'OK'
                callback obj
            when 'OVER_QUERY_LIMIT'
                timeZone.overQueryLimit = true
                setTimeout (-> timeZone.overQueryLimit = false), 10000
                alert obj.status
            else
                console.error obj
getTimeZone.overQueryLimit = false

# is a class with a marker, responsible for modal.
class Place
    @$modalInfo: $('#modal-info')
    @modalPlace: null
    # constructs an instance from marker and address, gets address if missed, gets Street View info and sets event listener.
    constructor: (options, @event, @address = null) ->
        @marker = new google.maps.Marker options
        google.maps.event.addListener @marker, 'click', @showInfo

    getStartDateTime: ->
        dateTime = @event.resource.start.dateTime ? (@event.resource.start.date + 'T00:00:00')
        if @startTimeZone?
            console.log @startTimeZone
            time = localTime new Date(dateTime), @startTimeZone.dstOffset + @startTimeZone.rawOffset
            {
                date: time.replace(/T.*/, '')
                time: time.replace(/.*T|[Z+-].*/g, '')
            }
        else
            {
                date: dateTime.replace(/T.*/, '')
                time: dateTime.replace(/.*T|[Z+-].*/g, '')
            }

    getEndDateTime: ->
        dateTime = @event.resource.end.dateTime ? (@event.resource.end.date + 'T00:00:00')
        if @endTimeZone?
            time = localTime new Date(dateTime), @endTimeZone.dstOffset + @endTimeZone.rawOffset
            {
                date: time.replace(/T.*/, '')
                time: time.replace(/.*T|[Z+-].*/g, '')
            }
        else
            {
                date: dateTime.replace(/T.*/, '')
                time: dateTime.replace(/.*T|[Z+-].*/g, '')
            }

    # shows its Modal Window.
    showInfo: =>
        @_setInfo()
        Place.$modalInfo.modal 'show'

    _setInfo: ->
        Place.modalPlace = @
        Place.$modalInfo.find('input[name="summary"]').val @event.resource.summary
        Place.$modalInfo.find('input[name="location"]').val @event.resource.location
        if @event.resource.start.date? and @event.resource.end.date?
            $('#form-event input[name="all-day"]')[0].checked = true
            $('#form-event input[name="all-day"]').trigger 'change'
            Place.$modalInfo.find('input[name="start-date"]').val @event.resource.start.date
            Place.$modalInfo.find('input[name="end-date"]').val @event.resource.end.date
        else if @event.resource.start.dateTime? and @event.resource.end.dateTime?
            $('#form-event input[name="all-day"]')[0].checked = false
            $('#form-event input[name="all-day"]').trigger 'change'
            getTimeZone new Date(@event.resource.start.dateTime), @marker.getPosition(), (obj) =>
                @startTimeZone = obj
                dateTime = @getStartDateTime()
                Place.$modalInfo.find('input[name="start-date"]').val dateTime.date
                Place.$modalInfo.find('input[name="start-time"]').val dateTime.time
            getTimeZone new Date(@event.resource.end.dateTime), @marker.getPosition(), (obj) =>
                @endTimeZone = obj
                dateTime = @getEndDateTime()
                Place.$modalInfo.find('input[name="end-date"]').val dateTime.date
                Place.$modalInfo.find('input[name="end-time"]').val dateTime.time
        else
            console.error 'inconsistent start and end'
        if @address
            $('#candidate').css 'display', 'block'
            $('#candidate-address').text @address
        else
            $('#candidate').css 'display', 'none'
        Place.$modalInfo.find('input[name="description"]').val @event.resource.description


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
        @candidates = null
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
                        @setGeolocation results[0].geometry.location.lat(), results[0].geometry.location.lng(), results[0].formatted_address
                        @update()
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
            , @

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
                            , @, e.formatted_address
                    setTimeout (=>
                        $("#map img[src=\"#{@icon.url}\"]").addClass 'candidate'
                    ), 500 # 500ms is adhoc number for waiting for DOM

    setGeolocation: (lat, lng, address) ->
        @resource.extendedProperties ?= {}
        @resource.extendedProperties.private ?= {}
        @resource.extendedProperties.private.geolocation = JSON.stringify
            lat: lat
            lng: lng
            address: address

    update: ->
        console.log @resource
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

    $('#button-show').on 'click', ->
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

    $('#button-confirm').on 'click', ->
        position = Place.modalPlace.marker.getPosition()
        Place.modalPlace.event.setGeolocation position.lat(), position.lng(), Place.modalPlace.geocodedAddress
        Place.modalPlace.event.update()
        Place.modalPlace.event.candidates.forEach (e) -> e.marker.setMap null
        Place.modalPlace.event.candidates = null
        Place.modalPlace.event.setPlace()
        $('#candidate').css 'display', 'none'

    $('#button-update').on 'click', ->
        updateFlag = false
        anEvent = Place.modalPlace.event
        if anEvent.resource.summary isnt $('#form-event input[name="summary"]').val()
            updateFlag = true
            anEvent.resource.summary = $('#form-event input[name="summary"]').val()
        if anEvent.resource.location isnt $('#form-event input[name="location"]').val()
            updateFlag = true
            anEvent.resource.location = $('#form-event input[name="location"]').val()
            delete anEvent.resource.extendedProperties.private.geolocation
        if $('#form-event input[name="all-day"]')[0].checked
            if anEvent.resource.start.date isnt $('#form-event input[name="start-date"]').val().replace(/-/g, '/')
                updateFlag = true
                delete anEvent.resource.start.dateTime
                anEvent.resource.start.date = $('#form-event input[name="start-date"]').val().replace(/-/g, '/')
            if anEvent.resource.end.date isnt $('#form-event input[name="end-date"]').val().replace(/-/g, '/')
                updateFlag = true
                delete anEvent.resource.end.dateTime
                anEvent.resource.end.date = $('#form-event input[name="end-date"]').val().replace(/-/g, '/')
        else
            timeZone = Place.modalPlace.startTimeZone
            startDateTime = new Date $('#form-event input[name="start-date"]').val().replace(/-/g, '/') + ' ' + $('#form-event input[name="start-time"]').val() + timeDifference(timeZone.dstOffset + timeZone.rawOffset)
            if new Date(anEvent.resource.start.dateTime).getTime() isnt startDateTime.getTime()
                updateFlag = true
                delete anEvent.resource.start.date
                anEvent.resource.start.dateTime = startDateTime.toISOString()
                anEvent.resource.start.timeZone = timeZone.timeZoneId
            timeZone = Place.modalPlace.endTimeZone
            endDateTime = new Date $('#form-event input[name="end-date"]').val().replace(/-/g, '/') + ' ' + $('#form-event input[name="end-time"]').val() + timeDifference(timeZone.dstOffset + timeZone.rawOffset)
            if new Date(anEvent.resource.end.dateTime).getTime() isnt endDateTime.getTime()
                updateFlag = true
                delete anEvent.resource.end.date
                anEvent.resource.end.dateTime = endDateTime.toISOString()
                anEvent.resource.end.timeZone = timeZone.timeZoneId
        if anEvent.resource.description isnt $('#form-event input[name="description"]').val()
            updateFlag = true
            anEvent.resource.description = $('#form-event input[name="description"]').val()
        anEvent.update() if updateFlag

    $('#form-event input[name="all-day"]').on 'change', ->
        $('#form-event input[name="start-time"]').css 'display', if @checked then 'none' else ''
        $('#form-event input[name="end-time"]').css 'display', if @checked then 'none' else ''

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

    geocoder = new google.maps.Geocoder()

# export

window.app =
    initialize: ->
        initializeGoogleMaps()
        initializeDOM()
    saveMapStatus: saveMapStatus
