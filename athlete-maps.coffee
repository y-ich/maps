Array::find = (predicate) -> @filter(predicate)[0] ? null

currentMarker = null
startMarker = null
directionsRenderer = null
map = null
infoWindow = null
$infoContent = null
history = null
graph = Raphael 'graph', innerWidth, $('#graph').innerHeight()

spinner = new Spinner()

elevationService = new google.maps.ElevationService()
elevationAlongSteps = (steps, callback) ->
    MAGIC = 300

    path = []
    for s in steps
        path = path.concat s.path

    totalResult = []
    aux = (index) ->
        elevationService.getElevationForLocations
                locations: path.slice(index, index + MAGIC)
        , (result, status) ->
            switch status
                when google.maps.ElevationStatus.OK
                    totalResult = totalResult.concat result
                    index += MAGIC
                    if index < path.length
                        $('#progress-bar').css 'width', index / (path.length - 1) * 100 + '%'
                        setTimeout (-> aux index), 1500
                    else
                        $('#progress-bar').css 'width', '0%'
                        callback totalResult
                when google.maps.ElevationStatus.OVER_QUERY_LIMIT
                    console.log status
                    setTimeout (-> aux index), 3000
                else
                    console.log status

    aux 0

drawElevation = (elevationResults) ->
    elevations = elevationResults.map (x) -> x.elevation
    slopes= [0]
    distances = [0]
    steepGo = 0
    steepBack = 0
    maxSlope = 0
    maxSlopeIndex = 0
    minSlope = 0
    minSlopeIndex = 0
    threshold = parseFloat $('#elevation input[name="threshold"]').val()
    for i in [1..elevationResults.length - 1]
        d = google.maps.geometry.spherical.computeDistanceBetween elevationResults[i - 1].location, elevationResults[i].location
        slope = if d != 0 then (elevations[i] - elevations[i - 1]) / d * 100 else slopes[slopes.length - 1]
        slopes.push slope
        if slope > maxSlope
            maxSlope = slope
            maxSlopeIndex = i
        if slope < minSlope
            minSlope = slope
            minSlopeIndex = i
        steepGo += d if slope > threshold
        steepBack += d if slope < -threshold
        distances.push distances[i - 1] + d
    distances = distances.map (e) -> e / 1000
    aux = ->
        graph.clear()
        graph.linechart 20, 0, innerWidth - 40, ($('#graph').innerHeight() - 20) / 2 - 10, distances, elevations,
            axis: '0 1 0 1'
        graph.linechart 20, ($('#graph').innerHeight() - 20) / 2 - 10, innerWidth - 40, $('#graph').innerHeight() / 2 - 10,
            [distances, [distances[0], distances[distances.length - 1]], [distances[maxSlopeIndex], distances[maxSlopeIndex]], [distances[minSlopeIndex], distances[minSlopeIndex]]],
            [slopes, [0, 0], [minSlope, maxSlope], [minSlope, maxSlope]],
            axis: '0 1 1 1'
        roadMessage = (max, steep) ->
            "max slope: #{Math.floor max}°  steep distance: #{Math.floor(steep / 100) / 10}km(#{Math.floor(steep / distances[distances.length - 1] * 100)}%)"
        $('#data').text 'way - ' + roadMessage(maxSlope, steepGo) + ' / way back - ' +roadMessage(-minSlope, steepBack)
    if $('#container').hasClass 'graph'
        aux()
    else
        $('#container').addClass 'graph'
        $('#graph').on $.support.transition.end, ->
            google.maps.event.trigger map, 'resize'
            aux()

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
                render = ->
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
                if $('#map-container').hasClass 'route'
                    render()
                else
                    $('#map-container').addClass 'route'
                    $('#panel').one $.support.transition.end, ->
                        google.maps.event.trigger map, 'resize'
                        render()
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

$('#elevation').on 'submit', (event) ->
    directions = directionsRenderer.getDirections()
    index = directionsRenderer.getRouteIndex() ? 0
    directionsInHistory = history.find (e) -> e.directionsResult is directions
    if directionsInHistory.elevationResults?[index]?
        drawElevation directionsInHistory.elevationResults[index]
    else
        steps = []
        for e in directions.routes[index].legs
            steps = steps.concat e.steps
        spinner.spin document.body
        elevationAlongSteps steps, (result) ->
            spinner.stop()
            directionsInHistory.elevationResults ?= []
            directionsInHistory.elevationResults[index] = result
            drawElevation result
    event.preventDefault()
