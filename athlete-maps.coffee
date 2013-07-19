Array::find = (predicate) -> @filter(predicate)[0] ? null

currentMarker = null
startMarker = null
directionsRenderer = null
map = null
infoWindow = null
$infoContent = null
history = null

elevationService = new google.maps.ElevationService()
elevationAlongSteps = (steps, callback) ->
    MAGIC = 300

    path = []
    for s in steps
        path = path.concat s.path

    deferredes = []
    results = []
    for i in [0..Math.floor((path.length - 1) / MAGIC)]
        deferred = $.Deferred()
        deferredes.push deferred
        setTimeout ((i, deferred) ->
            ->
                elevationService.getElevationForLocations
                        locations: path.slice(i * MAGIC, (i + 1) * MAGIC)
                    , (result, status) ->
                        if status is google.maps.ElevationStatus.OK
                            deferred.resolve()
                            results[i] = result
                        else
                            deferred.reject()
                            console.log status
        )(i, deferred), 2000 * i

    $.when.apply(window, deferredes).done(->
        result = results.reduce (a, b) -> a.concat b
        callback result
    ).fail ->
        console.log 'fail'

drawElevation = (elevationResults) ->
    elevations = elevationResults.map (x) -> x.elevation
    slopes= [0]
    distances = [0]
    for i in [0...elevationResults.length - 1]
        d = google.maps.geometry.spherical.computeDistanceBetween elevationResults[i].location, elevationResults[i + 1].location
        slopes.push if d != 0 then (elevations[i + 1] - elevations[i]) / d * 100 else slopes[slopes.length - 1]
        distances.push distances[i] + d
    $('#container').addClass 'graph'
    $('#graph').on $.support.transition.end, ->
        google.maps.event.trigger map, 'resize'
        r = Raphael 'graph', innerWidth, $('#graph').innerHeight()
        r.linechart 20, 0, innerWidth - 40, $('#graph').innerHeight() / 2 - 10, distances, elevations,
            axis: '0 1 0 1'
        r.linechart 20, $('#graph').innerHeight() / 2 - 10, innerWidth - 40, $('#graph').innerHeight() / 2 - 10, distances, slopes,
            axis: '0 1 1 1'

$infoContent = $('''
    <div>
        <p id="description"></p>
        <button id="start" type="button" class="btn">スタート</button>
        <button id="goal" type="button" class="btn">ゴール</button>
    </div>
    ''')

$infoContent.children('#start').on 'click', ->
    startMarker = currentMarker
    setTimeout (-> infoWindow.close()), 0 # 直接閉じると、クリックイベントがmapにバブルするので、閉じるタイミングをずらす。

$infoContent.children('#goal').on 'click', ->
    setTimeout (-> infoWindow.close()), 0
    new google.maps.DirectionsService().route
            avoidHighways: true
            avoidTolls: true
            destination: currentMarker.getPosition()
            origin: startMarker.getPosition()
            provideRouteAlternatives: true
            travelMode: google.maps.TravelMode.DRIVING
        , (result, status) ->
            history = []
            if status is google.maps.DirectionsStatus.OK
                startMarker.setMap null
                currentMarker.setMap null
                $('#map-container').addClass 'route'
                $('#panel').one $.support.transition.end, ->
                    google.maps.event.trigger map, 'resize'
                    if directionsRenderer?
                        directionsRenderer.setDirections result
                    else
                        history.push
                            directionsResult: result
                        directionsRenderer = new google.maps.DirectionsRenderer
                            directions: result
                            draggable: true
                            map: map
                            panel: $('#directions-panel')[0]
                        google.maps.event.addListener directionsRenderer, 'directions_changed', ->
                            history.push
                                directionsResult: @getDirections()
            else
                alert status

infoWindow = new google.maps.InfoWindow
    content: $infoContent[0]

setContent = (description) -> $infoContent.children('#description').text description

createMarker = (position) ->
    marker = new google.maps.Marker
        animation: google.maps.Animation.DROP
        draggable: true
        map: map
        position: position
    google.maps.event.addListener marker, 'click', ->
        currentMarker = this
        setContent @getPosition().toString()
        infoWindow.open map, this

map = new google.maps.Map document.getElementById('map'),
    center: new google.maps.LatLng(34.584199, 135.835163)
    zoom: 10
    mapTypeId: google.maps.MapTypeId.ROADMAP
    panControl: false

google.maps.event.addListener map, 'click', (event) ->
    createMarker event.latLng

autocomplete = new google.maps.places.Autocomplete $('#search')[0]
google.maps.event.addListener autocomplete, 'place_changed', ->
    place = autocomplete.getPlace()
    if place.geometry?
        map.panTo place.geometry.location
        new google.maps.Marker
            animation: google.maps.Animation.DROP
            draggable: true
            map: map
            position: place.geometry.location

$('#altitude').on 'click', ->
    directions = directionsRenderer.getDirections()
    index = directionsRenderer.getRouteIndex() ? 0
    directionsInHistory = history.find (e) -> e.directionsResult is directions
    if directionsInHistory.elevationResults?[index]?
        drawElevation directionsInHistory.elevationResults[index]
    else
        steps = []
        for e in directions.routes[index].legs
            steps = steps.concat e.steps
        elevationAlongSteps steps, (result) ->
            directionsInHistory.elevationResults ?= []
            directionsInHistory.elevationResults[index] = result
            drawElevation result
