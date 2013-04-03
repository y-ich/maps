# Google Maps Web App
# Copyright (C) 2012-2103 ICHIKAWA, Yuji (New 3 Rs) 

#
# constants
#

CLIENT_ID = '369757625302.apps.googleusercontent.com'
SCOPES = [
    'https://www.googleapis.com/auth/calendar'
]
MAP_STATUS = 'spacetime-map-status'
# TIME_ZONE_HOST = 'http://localhost:9292'
TIME_ZONE_HOST = 'http://safari-park.herokuapp.com'


#
# global variables
#

map = null
directionsRenderer = null
calendars= null # result of calenders list
currentCalendar = null
currentPlace = null
directionOrigin = null
geocoder = null
spinner = new Spinner color: '#000'

# Google OAuth 2.0 handler
handleAuthResult = (result) ->
    if result? and not result.error?
        gapi.client.load 'calendar', 'v3', ->
            $('#button-authorize').css 'display', 'none'
            $('#button-calendar').css 'display', ''
    else
        $('#button-authorize').text('このアプリ"EventMaps"にGoogleカレンダーへのアクセスを許可する')
                              .attr('disabled', null)
                              .addClass 'primary'


getLocalizedString = (key) ->
    if localizedStrings? then localizedStrings[key] ? key else key

setLocalExpressionInto = (id, english) ->
    el = document.getElementById id
    el.lastChild.data = getLocalizedString english if el?

localize = ->
    idWordPairs = []

    document.title = getLocalizedString 'EventMaps'
    # document.getElementById('search-input').placeholder = getLocalizedString 'Search or Address'
    setLocalExpressionInto key, value for key, value of idWordPairs

# saves current state into localStorage
saveMapStatus = () ->
    pos = map.getCenter()
    localStorage[MAP_STATUS] = JSON.stringify
        lat: pos.lat()
        lng: pos.lng()
        zoom: map.getZoom()

# returns strings, that shows time difference, from offset(sec).
timeDifference = (offset) ->
    twoDigitsFormat = (n) -> if n < 10 then '0' + n else n.toString()
    offsetHours = Math.floor(offset / (60 * 60))
    offsetMinutes = Math.floor(offset / 60 - offsetHours * 60)
    (if offset >= 0 then '+' else '-') + twoDigitsFormat(offsetHours) + twoDigitsFormat(offsetMinutes)

# returns local time specified by offset in string format.
# date is an instance of Date. offset is offset seconds including day-light-saving.
localTime = (date, offset) ->
    new Date(date.getTime() + offset * 1000).toISOString().replace /\..*Z/, timeDifference(offset)
    # ISOString is such as '2013-04-24T08:15:00.000Z'

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
                setTimeout (-> timeZone.overQueryLimit = false), 10000 # no reason of 10s.
                alert obj.status
            else
                console.error obj
getTimeZone.overQueryLimit = false

compareEventResources = (x, y) ->
    new Date(x.start.dateTime ? x.start.date + 'T00:00:00Z').getTime() - new Date(y.start.dateTime ? y.start.date + 'T00:00:00Z').getTime()

searchDirections = (origin, destination, travelMode) ->
    searchDirections.service.route
        destination: destination
        origin: origin
        travelMode: travelMode,
        (result, status) ->
            switch status
                when google.maps.DirectionsStatus.OK
                    directionsRenderer.setMap map
                    directionsRenderer.setDirections result
                else
                    directionsRenderer.setMap null
                    alert '道順がみつかりませんでした'

searchDirections.service = new google.maps.DirectionsService()


# is a class with a marker, responsible for modal.
class Place extends google.maps.Marker
    # Place is an extension of google.maps.Marker, but doen't extend it because google.maps.Marker is not a constructor function.

    @$modalInfo: $('#modal-info')
    @modalPlace: null

    # options is for Marker, @event is an Event for the Place.
    # optional @address means the Place is one of candicates and shows the address of the Place.
    constructor: (options, @event, @address = null) ->
        super options
        google.maps.event.addListener @, 'click', =>
            if directionOrigin?
                searchDirections directionOrigin, @getPosition(), google.maps.TravelMode.TRANSIT
                directionOrigin = null
            else
                @showInfo()

    # returns Event's time (date property and time property) in local time at the Place.
    # startOrEnd is 'start' or 'end'
    # If doesn't get time zone information, returns dateTime as its format.
    getDateTime: (startOrEnd) ->
        dateTime = @event.resource[startOrEnd].dateTime ? (@event.resource[startOrEnd].date + 'T00:00:00')
        if @["#{startOrEnd}TimeZone"]?
            time = localTime new Date(dateTime), @["#{startOrEnd}TimeZone"].dstOffset + @["#{startOrEnd}TimeZone"].rawOffset
            date: time.replace(/T.*/, '')
            time: time.replace(/.*T|[Z+-].*/g, '')
        else
            date: dateTime.replace(/T.*/, '')
            time: dateTime.replace(/.*T|[Z+-].*/g, '')

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
            setTime = (startOrEnd) =>
                dateTime = @getDateTime startOrEnd
                Place.$modalInfo.find("input[name=\"#{startOrEnd}-date\"]").val dateTime.date
                Place.$modalInfo.find("input[name=\"#{startOrEnd}-time\"]").val dateTime.time
            $('#form-event input[name="all-day"]')[0].checked = false
            $('#form-event input[name="all-day"]').trigger 'change'
            startDeferred = $.Deferred()
            endDeferred = $.Deferred()
            $.when(startDeferred, endDeferred).then -> spinner.stop()
            spinner.spin document.body
            if @startTimeZone?
                startDeferred.resolve()
                setTime 'start'
            else
                getTimeZone new Date(@event.resource.start.dateTime), @getPosition(), (obj) =>
                    startDeferred.resolve()
                    @startTimeZone = obj
                    setTime 'start'
            if @endTimeZone?
                endDeferred.resolve()
                setTime 'end'
            else
                getTimeZone new Date(@event.resource.end.dateTime), @getPosition(), (obj) =>
                    endDeferred.resolve()
                    @endTimeZone = obj
                    setTime 'end'
        else
            console.error 'inconsistent start and end'
        if @address
            $('#candidate').css 'display', 'block'
            $('#candidate-address').text @address
        else
            $('#candidate').css 'display', 'none'
        Place.$modalInfo.find('input[name="description"]').val @event.resource.description

# delegate
#for name, method of MapState.prototype when typeof method is 'function'
#    MapFSM.prototype[name] = ((name) ->
#        -> @setState @state[name](@))(name) # substantiation of name


# is a class of Google Calendar Event.
# is capable to geocode the location of events and saves it as extendedProperties.private.geolocation.
# Event.geocodeCount should be reset to 0 when starting simultaneous geocode requests 
class Event
    @events: []
    @mark: 'A' # next alphabetic marker
    @geocodeCount: 0 # Google accepts only ten simultaneous geocode requests. So count them.
    @shadow:
        url: 'http://www.google.com/mapfiles/shadow50.png'
        anchor: new google.maps.Point(10, 34)

    # clears all events.
    @clearAll: ->
        for e in Event.events
            e.clearMarkers()
        Event.events = []
        Event.mark = 'A'

    constructor: (@calendarId, @resource, centering = false, byClick = false) ->
        @resource.summary ?= '新しい予定'
        @resource.location ?= ''
        @resource.description ?= ''
        @resource.start ?= dateTime: new Date().toISOString()
        @resource.end ?= dateTime: new Date().toISOString()

        @candidates = null
        if @latLng()? or (@resource.location? and @resource.location isnt '')
            @icon =
                url: "http://www.google.com/mapfiles/marker#{Event.mark}.png"
            Event.mark = String.fromCharCode Event.mark.charCodeAt(0) + 1 if Event.mark isnt 'Z'
            @tryToSetPlace centering, byClick
        Event.events.push @

    clearMarkers: ->
        @place.setMap null if @place?
        @place = null
        e.setMap null for e in @candidates if @candicates?
        @candidates = null

    latLng: ->
        if @resource.extendedProperties?.private?.geolocation?
            geolocation = JSON.parse @resource.extendedProperties.private.geolocation
            new google.maps.LatLng geolocation.lat, geolocation.lng
        else
            null

    address: ->
        if @resource.extendedProperties?.private?.geolocation?
            geolocation = JSON.parse @resource.extendedProperties.private.geolocation
            geolocation.address
        else
            null

    geocode: (callback) -> # the argument of callback is the first arugment of geocode callback.
        if Event.geocodeCount > 10
            console.log 'too many geocoding requests'
            return false
        latLng = @latLng()
        if latLng?
            options = location: latLng
        else if @resource.location isnt ''
            options = address: @resource.location
        else
            console.error 'no hints for geocode'
            return

        geocoder.geocode options, (results, status) =>
            switch status
                when google.maps.GeocoderStatus.OK
                    if results.length is 1
                        @setGeolocation results[0].geometry.location.lat(), results[0].geometry.location.lng(), results[0].formatted_address
                        @update()
                    callback results
                when google.maps.GeocoderStatus.ZERO_RESULTS
                    setTimeout (-> alert "#{@resource.location}が見つかりません"), 0
                else
                    console.error status
        Event.geocodeCount += 1

    setPlace: (byClick = false) ->
        latLng = @latLng()
        unless latLng
            @place = null
            return null

        @place = new Place
            map: map
            position: latLng
            icon: @icon ? null
            shadow: if @icon? then Event.shadow else null
            title: @resource.location,
            animation: if byClick then google.maps.Animation.DROP else null,
            @
        google.maps.event.addListener @place, 'animation_changed', -> @showInfo() if byClick

    tryToSetPlace: (centering, byClick) ->
        @setPlace byClick
        if @place? and centering
            map.setCenter @place.getPosition()
            currentPlace = @place

        if not (@place? and @address()?) # if place and/or address is unknown
            @geocode (results) =>
                if @place? # if new event by clicking map
                    @setGeolocation results[0].geometry.location.lat(), results[0].geometry.location.lng(), results[0].formatted_address
                else if results.length == 1
                    @setPlace byClick
                    if @place? and centering
                        map.setCenter @place.getPosition()
                        currentPlace = @place
                else
                    @candidates = []
                    for e in results
                        @candidates.push new Place
                            map: map
                            position: e.geometry.location
                            icon: @icon ? null
                            shadow: if @icon? then Event.shadow else null
                            title: @resource.location + '?'
                            optimized: false,
                            @, e.formatted_address
                    setTimeout (=> $("#map img[src=\"#{@icon.url}\"]").addClass 'candidate'), 500 # 500ms is adhoc number for waiting for DOM
                    if centering
                        map.setCenter @candidates[0].getPosition()
                        currentPlace = @candidates[0]

    setGeolocation: (lat, lng, address) ->
        @resource.extendedProperties ?= {}
        @resource.extendedProperties.private ?= {}
        @resource.extendedProperties.private.geolocation = JSON.stringify
            lat: lat
            lng: lng
            address: address
        @resource.location = address unless @resource.location? and @resource.location isnt ''

    update: ->
        if @calendarId?
            gapi.client.calendar.events.update(
                calendarId: @calendarId
                eventId: @resource.id
                resource: @resource
            ).execute (resp) ->
                if resp.error?
                    console.error 'gapi.client.calendar.events.update', resp
        else
            $('#modal-calendar').modal 'show'

    insert: ->
        if @calendarId?
            gapi.client.calendar.events.insert(
                calendarId: @calendarId
                resource: @resource
            ).execute (resp) =>
                if resp.error?
                    console.error 'gapi.client.calendar.events.update', resp
                else
                    @resource = resp.result
        else
            $('#modal-calendar').modal 'show'

initializeDOM = ->
    localize()
    $('#container').css 'display', ''

    new FastClick document.body

    $('#button-authorize').on 'click', ->
        gapi.auth.authorize
                'client_id': CLIENT_ID
                'scope': SCOPES
                'immediate': false
            , handleAuthResult

    $calendarList = $('#calendar-list')
    $('#modal-calendar').on 'show', (event) ->
        req = gapi.client.calendar.calendarList.list()
        req.execute (resp) ->
            if resp.error?
                console.error resp
            else
                calendars = resp.items
                $calendarList.html '<option value="new">新規作成</option>' + ("<option value=\"#{e.id}\">#{e.summary}</option>" for e in calendars).join('')

    $('#button-show').on 'click', ->
        if Event.events.length > 0 and Event.events[0].calendarId?
            Event.clearAll()
        id = $calendarList.children('option:selected').attr 'value'
        if id is 'new'
            if name = prompt '新しいカレンダーに名前をつけてください'
                req = gapi.client.calendar.calendars.insert
                    resource:
                        summary: name
                req.execute (resp) ->
                    if resp.error?
                        alert 'カレンダーが作成できませんでした'
                    else
                        currentCalendar = resp.result
                        calendars.push currentCalendar
                        e.calendarId = currentCalendar.id for e in Event.events
        else
            for e in calendars
                if e.id is id
                    currentCalendar = e
                    break
            e.calendarId = currentCalendar.id for e in Event.events
            options =
                calendarId: id
            options.timeMin = $('#form-calendar [name="start-date"]')[0].value + 'T00:00:00Z' unless $('#form-calendar [name="start-date"]')[0].value is ''
            options.timeMax = $('#form-calendar [name="end-date"]')[0].value + 'T00:00:00Z' unless $('#form-calendar [name="end-date"]')[0].value is ''
            req = gapi.client.calendar.events.list options
            req.execute (resp) ->
                if resp.error?
                    console.error resp
                else if resp.items?.length > 0
                    resp.items.sort compareEventResources
                    Event.geocodeCount = 0
                    for e, i in resp.items
                        event = new Event id, e, i == 0

    $('#button-confirm').on 'click', ->
        position = Place.modalPlace.getPosition()
        Place.modalPlace.event.setGeolocation position.lat(), position.lng(), Place.modalPlace.geocodedAddress
        Place.modalPlace.event.update()
        Place.modalPlace.event.clearMarkers()
        Place.modalPlace.event.setPlace()
        $('#candidate').css 'display', 'none'

    $('#button-update').on 'click', ->
        anEvent = Place.modalPlace.event
        if anEvent.resource.id?
            updateFlag = false
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
        else
            anEvent.insert()

    $('#modal-info').on 'hide', -> spinner.stop()

    $('#form-event input[name="all-day"]').on 'change', ->
        $('#form-event input[name="start-time"]').css 'display', if @checked then 'none' else ''
        $('#form-event input[name="end-time"]').css 'display', if @checked then 'none' else ''

    $('#button-delete').on 'click', ->
        anEvent = Place.modalPlace.event
        if anEvent.calendarId? and anEvent.resource.id?
            req = gapi.client.calendar.events.delete
                calendarId: anEvent.calendarId
                eventId: anEvent.resource.id
            req.execute (resp) ->
                if resp.error?
                    alert '予定が削除できませんでした'
        Event.events.splice Event.events.indexOf anEvent, 1
        anEvent.clearMarkers()
        Place.modalPlace = null

    $('#form-search').on 'submit', (event) ->
        location = $(this).children('[name="search"]').val()
        if location? and location isnt ''
            geocoder.geocode { address: location }, (results, status) ->
                switch status
                    when google.maps.GeocoderStatus.OK
                        map.setCenter results[0].geometry.location
                    when google.maps.GeocoderStatus.ZERO_RESULTS
                        setTimeout (-> alert '見つかりませんでした'), 0
                    else
                        console.error status
        event.preventDefault()

    $('#button-prev, #button-next').on 'click', ->
        sorted = Event.events.sort (x, y) -> compareEventResources x.resource, y.resource
        EventIndex = if currentPlace? then sorted.indexOf currentPlace.event else 0
        if Event.events[EventIndex].candidates?
            candidateIndex = Event.events[EventIndex].candidates.indexOf currentPlace
            if this.id is 'button-prev'
                candidateIndex -= 1
                candidateIndex = null if candidateIndex < 0
            else
                candidateIndex += 1
                candidateIndex = null if candidateIndex >= Event.events[EventIndex].candidates.length
        if candidateIndex?
            currentPlace = Event.events[EventIndex].candidates[candidateIndex]
        else
            if this.id is 'button-prev'
                EventIndex -= 1
                EventIndex = sorted.length - 1 if EventIndex < 0
                candidateIndex = Event.events[EventIndex].candidates?.length - 1
            else
                EventIndex += 1
                EventIndex = 0 if EventIndex >= sorted.length
                candidateIndex = 0
            currentPlace = sorted[EventIndex].place ? sorted[EventIndex].candidates[candidateIndex]
        map.setCenter (currentPlace).getPosition()

    $('#button-direction').on 'click', (event) ->
        directionOrigin = currentPlace.getPosition()
        alert '目的地のマーカをクリックしてください'

initializeGoogleMaps = ->
    mapOptions =
        mapTypeId: google.maps.MapTypeId.ROADMAP
        disableDefaultUI: /iPad|iPhone/.test(navigator.userAgent)
        zoomControlOptions:
            position: google.maps.ControlPosition.LEFT_CENTER
        panControlOptions:
            position: google.maps.ControlPosition.LEFT_CENTER

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

    google.maps.event.addListener map, 'click', (event) ->
        new Event currentCalendar?.id,
            extendedProperties:
                private:
                    geolocation: JSON.stringify(
                        lat: event.latLng.lat()
                        lng: event.latLng.lng()
                    ),
            false, true
    geocoder = new google.maps.Geocoder()

    directionsRenderer = new google.maps.DirectionsRenderer
        hideRouteList: false
        map: map
        panel: $('#directions-panel')[0]

# export

window.app =
    initialize: ->
        initializeGoogleMaps()
        initializeDOM()
    saveMapStatus: saveMapStatus

window.handleClientLoad = -> setTimeout (->
        gapi.auth.authorize
                'client_id': CLIENT_ID
                'scope': SCOPES
                'immediate': true
            , handleAuthResult
    ), 1
