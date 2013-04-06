# Google Maps Web App
# Copyright (C) 2012-2103 ICHIKAWA, Yuji (New 3 Rs) 

#
# constants
#

CLIENT_ID = '369757625302.apps.googleusercontent.com'
SCOPES = ['https://www.googleapis.com/auth/calendar']
MAP_STATUS = 'spacetime-map-status'
# TIME_ZONE_HOST = 'http://localhost:9292'
TIME_ZONE_HOST = 'http://safari-park.herokuapp.com'
APP_NAME = 'EventMaps'

#
# global variables
#

map = null
directionsRenderer = null
geocoder = null
calendars= null # result of calenders list
currentCalendar = null
currentPlace = null
directionsCondition =
    origin: null
    destination: null
    time: null
directions = null
spinner = new Spinner color: '#000'

#
# generic functions
#

# sums in an array
sum = (array) ->
    array.reduce (a, b) -> a + b

# sums after some transformation
mapSum = (array, fn) ->
    array.map(fn).reduce (a, b) -> a + b


# localization
getLocalizedString = (key) ->
    if localizedStrings? then localizedStrings[key] ? key else key

setLocalExpressionInto = (id, english) ->
    el = document.getElementById id
    el.lastChild.data = getLocalizedString english if el?

localize = ->
    idWordPairs = []
    document.title = getLocalizedString APP_NAME
    # document.getElementById('search-input').placeholder = getLocalizedString 'Search or Address'
    setLocalExpressionInto key, value for key, value of idWordPairs


#
# Time utilities
#

# returns strings, that shows time difference, from offset(sec), such as '+0900'.
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
                getTimeZone.overQueryLimit = true
                setTimeout (-> getTimeZone.overQueryLimit = false), 1000 # no reason of 1s.
                alert obj.status
            else
                console.error obj
getTimeZone.overQueryLimit = false


# compares start times of event resources
compareEventResources = (x, y) ->
    new Date(x.start.dateTime ? x.start.date + 'T00:00:00Z').getTime() - new Date(y.start.dateTime ? y.start.date + 'T00:00:00Z').getTime()

# Google OAuth 2.0 handler
handleAuthResult = (result) ->
    if result? and not result.error?
        gapi.client.load 'calendar', 'v3', ->
            $('#button-authorize').css 'display', 'none'
            $('#button-calendar').css 'display', ''
    else
        $('#button-authorize').text("このアプリ\"#{APP_NAME}\"にGoogleカレンダーへのアクセスを許可する")
                              .attr('disabled', null)
                              .addClass 'primary'

# searches directions in all travel modes
searchDirections = (origin, destination, departureTime, callback) ->
    travelModes = [
        google.maps.TravelMode.BICYCLING
        google.maps.TravelMode.DRIVING
        google.maps.TravelMode.TRANSIT
        google.maps.TravelMode.WALKING
    ]
    deferreds = []
    results= []

    for e in travelModes
        deferred = $.Deferred()
        deferreds.push deferred
        options =
            destination: destination
            origin: origin
            travelMode: e
        options.transitOptions = departureTime: departureTime if departureTime?
        searchDirections.service.route options, ((travelMode, deferred) ->
                (result, status) ->
                    switch status
                        when google.maps.DirectionsStatus.OK
                            result.travelMode = travelMode
                            results.push result
                    deferred.resolve()
            )(e, deferred)
    $.when.apply(window, deferreds).then ->
        callback results

searchDirections.service = new google.maps.DirectionsService()

# saves current state into localStorage
saveMapStatus = () ->
    pos = map.getCenter()
    localStorage[MAP_STATUS] = JSON.stringify
        lat: pos.lat()
        lng: pos.lng()
        zoom: map.getZoom()

# is a class with a marker, responsible for modal.
class Place extends google.maps.Marker
    # options is for Marker, @event is an Event for the Place.
    # optional @candidateAddress means the Place is one of candicates and shows the address of the Place.
    constructor: (options, @event, @candidateAddress = null) ->
        super options
        google.maps.event.addListener @, 'click', =>
            if directionsCondition.origin? and not directionsCondition.destination?
                directionsCondition.destination = @
                time = switch directionsCondition.time
                    when 'now' then new Date()
                    when 'origin' then directionsCondition.origin.event.getDate('end')
                    when 'destination' then @event.getDate('start')
                    else null
                searchDirections directionsCondition.origin.getPosition(), @getPosition(), time, (results) ->
                    for result, i in results
                        for route in result.routes
                            route.distance = mapSum result.routes[0].legs, (e) -> e.distance.value
                            route.duration = mapSum result.routes[0].legs, (e) -> e.duration.value
                    results.sort (x, y) -> x.routes[0].duration - y.routes[0].duration
                    directionsRenderer.setDirections results[0]
                    directionsRenderer.setMap map
                    map.setMapTypeId switch results[0].travelMode
                        when google.maps.TravelMode.BICYCLING, google.maps.TravelMode.WALKING then google.maps.MapTypeId.TERRAIN
                        else google.maps.MapTypeId.ROADMAP
                    $('#button-route-info').removeClass 'hide'
                    directions =
                        results: results
                        index: 0
                        routeIndex: 0
            else
                @showInfo()

    # returns Event's time (date property and time property) in local time at the Place.
    # startOrEnd is 'start' or 'end'
    # If doesn't get time zone information, returns dateTime as its format.
    getDateTime: (startOrEnd) ->
        dateTime = @event.resource[startOrEnd].dateTime ? @event.resource[startOrEnd].date + 'T00:00:00Z'
        if @["#{startOrEnd}TimeZone"]?
            time = localTime new Date(dateTime), @["#{startOrEnd}TimeZone"].dstOffset + @["#{startOrEnd}TimeZone"].rawOffset
            date: time.replace(/T.*/, '')
            time: time.replace(/.*T|[Z+-].*/g, '')
        else
            date: dateTime.replace(/T.*/, '')
            time: dateTime.replace(/.*T|[Z+-].*/g, '')

    # shows its Modal Window.
    showInfo: =>
        @event.setModal @
        Event.$modal.modal 'show'
        # cancels direction mode
        directionsCondition =
            origin: null
            destination: null
            time: null
        directions = null
        directionsRenderer.setMap null
        map.setMapTypeId google.maps.MapTypeId.ROADMAP
        $('#button-route-info').addClass 'hide'


# delegate
#for name, method of MapState.prototype when typeof method is 'function'
#    MapFSM.prototype[name] = ((name) ->
#        -> @setState @state[name](@))(name) # substantiation of name


# is a class of Google Calendar Event.
# is capable to geocode the location of events and saves it as extendedProperties.private.geolocation.
# Event.geocodeCount should be reset to 0 when starting simultaneous geocode requests 
class Event
    @$modal: $('#modal-info')
    @events: []
    @placeNumber: 0
    @geocodeCount: 0 # Google accepts only ten simultaneous geocode requests. So count them.
    @shadow:
        url: 'http://www.google.com/mapfiles/shadow50.png'
        anchor: new google.maps.Point(10, 34)

    # clears all events.
    @clearAll: ->
        for e in Event.events
            e.clearMarkers()
        Event.events = []
        Event.placeNumber = 0

    constructor: (@calendarId, @resource, centering = false, byClick = false) ->
        @resource.summary ?= '新しい予定'
        @resource.location ?= ''
        @resource.description ?= ''
        @resource.start ?= dateTime: new Date().toISOString()
        @resource.end ?= dateTime: new Date().toISOString()
        @dirty = false

        @candidates = null
        if @getPosition()? or (@resource.location? and @resource.location isnt '')
            @placeNumber= Event.placeNumber
            Event.placeNumber += 1
            @tryToSetPlace centering, byClick
        Event.events.push @

    clearMarkers: ->
        @place.setMap null if @place?
        @place = null
        e.setMap null for e in @candidates if @candidates?
        @candidates = null

    # returns Event's Date.
    getDate: (startOrEnd) ->
        new Date @resource[startOrEnd].dateTime ? @resource[startOrEnd].date + if startOrEnd is 'start' then 'T00:00:00Z' else 'T23:59:59Z'

    getPosition: ->
        if @resource.extendedProperties?.private?.geolocation?
            geolocation = JSON.parse @resource.extendedProperties.private.geolocation
            if not geolocation.location? or geolocation.location is @resource.location
                new google.maps.LatLng geolocation.lat, geolocation.lng
            else null
        else
            null

    getAddress: ->
        if @resource.extendedProperties?.private?.geolocation?
            geolocation = JSON.parse @resource.extendedProperties.private.geolocation
            geolocation.address
        else
            null

    setGeolocation: (lat, lng, address) ->
        @resource.extendedProperties ?= {}
        @resource.extendedProperties.private ?= {}
        @resource.location = address unless @resource.location? and @resource.location isnt ''
        @resource.extendedProperties.private.geolocation = JSON.stringify
            lat: lat
            lng: lng
            address: address
            location: @resource.location

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

    geocode: (callback) -> # the argument of callback is the first arugment of geocode callback.
        if Event.geocodeCount > 10
            console.log 'too many geocoding requests'
            return false
        latLng = @getPosition()
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
                    setTimeout (=> alert "#{@resource.location}が見つかりません"), 0
                else
                    console.error status
        Event.geocodeCount += 1

    getIcon: (candidate = false) ->
        remainder = (m, n) -> m - Math.floor(m / n) * n
        alphabet = String.fromCharCode Math.min 'A'.charCodeAt(0) + remainder(@placeNumber, 26), 'Z'.charCodeAt(0)
        if candidate
            url: "http://maps.google.com/mapfiles/marker_grey#{alphabet}.png"
        else
            switch Math.floor @placeNumber / 26
                when 0
                    url: "http://maps.google.com/mapfiles/marker#{alphabet}.png"
                when 1
                    url: "http://maps.google.com/mapfiles/marker_orange#{alphabet}.png"
                when 2
                    url: "http://maps.google.com/mapfiles/marker_yellow#{alphabet}.png"
                when 3
                    url: "http://maps.google.com/mapfiles/marker_green#{alphabet}.png"
                else
                    url: "http://maps.google.com/mapfiles/marker_blue#{alphabet}.png"

    setPlace: (byClick = false) ->
        latLng = @getPosition()
        unless latLng
            @place = null
            return null

        @place = new Place
            map: map
            position: latLng
            icon: @getIcon()
            shadow: Event.shadow
            title: @resource.location,
            animation: if byClick then google.maps.Animation.DROP else null,
            @
        google.maps.event.addListener @place, 'animation_changed', -> @showInfo() if byClick

    tryToSetPlace: (centering, byClick, callback = ->) ->
        @setPlace byClick
        if @place? and centering
            map.setCenter @place.getPosition()
            currentPlace = @place

        if @place? and @getAddress()?
            callback()
            return
        @geocode (results) =>
            if byClick
                @setGeolocation results[0].geometry.location.lat(), results[0].geometry.location.lng(), results[0].formatted_address
            else if results.length == 1
                @setGeolocation results[0].geometry.location.lat(), results[0].geometry.location.lng(), results[0].formatted_address
                @setPlace()
                if @place? and centering
                    map.setCenter @place.getPosition()
                    currentPlace = @place
            else
                @candidates = []
                for e in results
                    @candidates.push new Place
                        map: map
                        position: e.geometry.location
                        icon: @getIcon(true)
                        shadow: Event.shadow
                        title: @resource.location + '?'
                        optimized: false,
                        @, e.formatted_address
                if centering
                    map.setCenter @candidates[0].getPosition()
                    currentPlace = @candidates[0]
            callback()

    setModal: (place) ->
        Event.$modal.data 'place', place
        currentPlace = place
        Event.$modal.find('input[name="summary"]').val @resource.summary
        Event.$modal.find('input[name="location"]').val @resource.location
        if @resource.start.date? and @resource.end.date?
            $('#form-event input[name="all-day"]')[0].checked = true
            $('#form-event input[name="all-day"]').trigger 'change'
            Event.$modal.find('input[name="start-date"]').val @resource.start.date
            Event.$modal.find('input[name="end-date"]').val @resource.end.date
        else if @resource.start.dateTime? and @resource.end.dateTime?
            setTime = (startOrEnd) ->
                dateTime = place.getDateTime startOrEnd
                Event.$modal.find("input[name=\"#{startOrEnd}-date\"]").val dateTime.date
                Event.$modal.find("input[name=\"#{startOrEnd}-time\"]").val dateTime.time
            $('#form-event input[name="all-day"]')[0].checked = false
            $('#form-event input[name="all-day"]').trigger 'change'
            startDeferred = $.Deferred()
            endDeferred = $.Deferred()
            $.when(startDeferred, endDeferred).then -> spinner.stop()
            spinner.spin document.body
            if place.startTimeZone?
                startDeferred.resolve()
                setTime 'start'
            else
                getTimeZone new Date(@resource.start.dateTime), place.getPosition(), (obj) ->
                    startDeferred.resolve()
                    place.startTimeZone = obj
                    setTime 'start'
            if place.endTimeZone?
                endDeferred.resolve()
                setTime 'end'
            else
                getTimeZone new Date(@resource.end.dateTime), place.getPosition(), (obj) ->
                    endDeferred.resolve()
                    place.endTimeZone = obj
                    setTime 'end'
        else
            console.error 'inconsistent start and end'
        if @candidates?
            $('#candidate').css 'display', 'block'
            $('#candidate select[name="candidate"]').html ("<option value=\"#{i}\" #{if e is place then 'selected' else ''}>#{e.candidateAddress}</option>" for e, i in @candidates).join ''
        else
            $('#candidate').css 'display', 'none'
        Event.$modal.find('input[name="description"]').val @resource.description

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
        currentPlace = null
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
                        event = new Event id, e

    $('#button-confirm').on 'click', ->
        candidateIndex = parseInt $('#form-event select[name="candidate"]').val()
        candidate = Event.$modal.data('place').event.candidates[candidateIndex]
        position = candidate.getPosition()
        Event.$modal.data('place').event.setGeolocation position.lat(), position.lng(), candidate.candidateAddress
        Event.$modal.data('place').event.dirty = true
        Event.$modal.data('place').event.clearMarkers()
        Event.$modal.data('place').event.setPlace()
        $('#candidate').css 'display', 'none'

    $('#button-update').on 'click', ->
        anEvent = Event.$modal.data('place').event
        if anEvent.resource.id?
            if anEvent.resource.summary isnt $('#form-event input[name="summary"]').val()
                anEvent.dirty = true
                anEvent.resource.summary = $('#form-event input[name="summary"]').val()
            if anEvent.resource.location isnt $('#form-event input[name="location"]').val()
                anEvent.dirty = true
                anEvent.resource.location = $('#form-event input[name="location"]').val()
                delete anEvent.resource.extendedProperties.private.geolocation
            if $('#form-event input[name="all-day"]')[0].checked
                if anEvent.resource.start.date isnt $('#form-event input[name="start-date"]').val().replace(/-/g, '/')
                    anEvent.dirty = true
                    delete anEvent.resource.start.dateTime
                    anEvent.resource.start.date = $('#form-event input[name="start-date"]').val().replace(/-/g, '/')
                if anEvent.resource.end.date isnt $('#form-event input[name="end-date"]').val().replace(/-/g, '/')
                    anEvent.dirty = true
                    delete anEvent.resource.end.dateTime
                    anEvent.resource.end.date = $('#form-event input[name="end-date"]').val().replace(/-/g, '/')
            else
                timeZone = Event.$modal.data('place').startTimeZone
                startDateTime = new Date $('#form-event input[name="start-date"]').val().replace(/-/g, '/') + ' ' + $('#form-event input[name="start-time"]').val() + timeDifference(timeZone.dstOffset + timeZone.rawOffset)
                if new Date(anEvent.resource.start.dateTime).getTime() isnt startDateTime.getTime()
                    anEvent.dirty = true
                    delete anEvent.resource.start.date
                    anEvent.resource.start.dateTime = startDateTime.toISOString()
                    anEvent.resource.start.timeZone = timeZone.timeZoneId
                timeZone = Event.$modal.data('place').endTimeZone
                endDateTime = new Date $('#form-event input[name="end-date"]').val().replace(/-/g, '/') + ' ' + $('#form-event input[name="end-time"]').val() + timeDifference(timeZone.dstOffset + timeZone.rawOffset)
                if new Date(anEvent.resource.end.dateTime).getTime() isnt endDateTime.getTime()
                    anEvent.dirty = true
                    delete anEvent.resource.end.date
                    anEvent.resource.end.dateTime = endDateTime.toISOString()
                    anEvent.resource.end.timeZone = timeZone.timeZoneId
            if anEvent.resource.description isnt $('#form-event input[name="description"]').val()
                anEvent.dirty = true
                anEvent.resource.description = $('#form-event input[name="description"]').val()
            anEvent.update() if anEvent.dirty
        else
            anEvent.insert()

    $('#modal-info').on 'hide', -> spinner.stop()

    $('#form-event input[name="all-day"]').on 'change', ->
        $('#form-event input[name="start-time"]').css 'display', if @checked then 'none' else ''
        $('#form-event input[name="end-time"]').css 'display', if @checked then 'none' else ''

    $('#button-delete').on 'click', ->
        anEvent = Event.$modal.data('place').event
        if anEvent.calendarId? and anEvent.resource.id?
            req = gapi.client.calendar.events.delete
                calendarId: anEvent.calendarId
                eventId: anEvent.resource.id
            req.execute (resp) ->
                if resp.error?
                    alert '予定が削除できませんでした'
        Event.events.splice Event.events.indexOf anEvent, 1
        anEvent.clearMarkers()
        Event.$modal.data 'place', null

    $('#button-prev, #button-next').on 'click', ->
        if directions?
            if directions.results.length == 1 and directions.results[0].routes.length == 1
                alert '道順は１つしか見つかりませんでした'
                return
            if this.id is 'buttion-prev'
                directions.routeIndex -= 1
                if directions.routeIndex < 0
                    directions.index -= 1
                    if directions.index < 0
                        directions.index = directions.results.length - 1
                    directionsRenderer.setDirections directions.results[directions.index]
                    map.setMapTypeId switch directions.results[directions.index].travelMode
                        when google.maps.TravelMode.BICYCLING, google.maps.TravelMode.WALKING then google.maps.MapTypeId.TERRAIN
                        else google.maps.MapTypeId.ROADMAP
                    directions.routeIdex = directions.results[directions.index].routes.length - 1
            else
                directions.routeIndex += 1
                if directions.routeIndex >= directions.results[directions.index].routes.length
                    directions.index += 1
                    if directions.index >= directions.results.length
                        directions.index = 0
                    directionsRenderer.setDirections directions.results[directions.index]
                    map.setMapTypeId switch directions.results[directions.index].travelMode
                        when google.maps.TravelMode.BICYCLING, google.maps.TravelMode.WALKING then google.maps.MapTypeId.TERRAIN
                        else google.maps.MapTypeId.ROADMAP
                    directions.routeIdex = 0
            directionsRenderer.setRouteIndex directions.routeIdex
        else
            return if Event.events.length == 0
            sorted = Event.events.filter((e) -> e.place? or e.candidates?).sort (x, y) -> compareEventResources x.resource, y.resource
            if currentPlace?
                eventIndex = sorted.indexOf currentPlace.event
                if Event.events[eventIndex].candidates?
                    candidateIndex = Event.events[eventIndex].candidates.indexOf currentPlace
                    if this.id is 'button-prev'
                        candidateIndex -= 1
                        candidateIndex = null if candidateIndex < 0
                    else
                        candidateIndex += 1
                        candidateIndex = null if candidateIndex >= Event.events[eventIndex].candidates.length
                if candidateIndex?
                    currentPlace = Event.events[eventIndex].candidates[candidateIndex]
                else
                    if this.id is 'button-prev'
                        eventIndex -= 1
                        eventIndex = sorted.length - 1 if eventIndex < 0
                        candidateIndex = Event.events[eventIndex].candidates?.length - 1
                    else
                        eventIndex += 1
                        eventIndex = 0 if eventIndex >= sorted.length
                        candidateIndex = 0
                    currentPlace = sorted[eventIndex].place ? sorted[eventIndex].candidates[candidateIndex]
            else if this.id is 'button-next'
                currentPlace = sorted[0].place ? sorted[0].candidates[0]
            else
                currentPlace = sorted[sorted.length - 1].place ? sorted[sorted.length - 1].candidates[sorted[sorted.length - 1].candidates.length - 1]
            map.panTo currentPlace.getPosition()

    $('#button-direction').on 'click', (event) ->
        directionsCondition.origin = Event.$modal.data 'place'
        $('#modal-directions').modal 'show'

    $('#button-direction-search').on 'click', (event) ->
        directionsCondition.time = $('#form-directions input:checked').val()

    $('#candidate select[name="candidate"]').on 'change', (event) ->
        Event.$modal.data 'place', Event.$modal.data('place').event.candidates[parseInt @value]
        map.panTo Event.$modal.data('place').getPosition()

    $('#button-search').on 'click', (event) ->
        Event.$modal.data('place').event.resource.location = $('#form-event input[name="location"]').val()
        Event.$modal.data('place').event.clearMarkers()
        Event.$modal.data('place').event.resource.extendedProperties?.private?.geolocation = null
        Event.$modal.data('place').event.tryToSetPlace true, false, -> currentPlace.event.setModal currentPlace

    $('#button-route-info').on 'click', ->
        if $('#directions-panel').hasClass 'hide'
            $('#directions-panel').removeClass 'hide'
        else
            $('#directions-panel').addClass 'hide'

    $('#directions-panel').on 'click', ->
        $('#directions-panel').addClass 'hide'

initializeGoogleMaps = (callback = ->) ->
    mapOptions =
        mapTypeId: google.maps.MapTypeId.ROADMAP
        disableDefaultUI: /iPad|iPhone/.test(navigator.userAgent)
        mapTypeControl: false
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

    callbackId = map.addListener 'tilesloaded', ->
        google.maps.event.removeListener callbackId
        callback()

    map.addListener 'click', (event) ->
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
    initialize: (mapsCallback) ->
        initializeGoogleMaps mapsCallback
        initializeDOM()
    saveMapStatus: saveMapStatus

window.handleClientLoad = -> setTimeout (->
        gapi.auth.authorize
                'client_id': CLIENT_ID
                'scope': SCOPES
                'immediate': true
            , handleAuthResult
    ), 1
