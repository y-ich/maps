# Google Maps Web App
# Copyright (C) 2012-2103 ICHIKAWA, Yuji (New 3 Rs) 

tracer = null
map = null
fusionTablesLayers = []

saveMapStatus = ->

saveOtherStatus = ->

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

initializeDOM = ->
    localize()
    $('#container').css 'display', ''
    $gbutton = $('#button-google-drive')
    $gbutton.on 'click', (event) ->
        gapi.auth.authorize
                'client_id': CLIENT_ID
                'scope': SCOPES
                'immediate': false
            , handleAuthResult

    $fusionTables = $('#fusion-tables')
    checked = (column) ->
        if $fusionTables.find("input[value=#{column.id}]:checked").length > 0
            'checked'
        else
            ''
    $('#modal-fusion-tables').on 'show', (event) ->
        searchFiles 'mimeType = "application/vnd.google-apps.fusiontable"', (result) ->
                $fusionTables.html ("<label><input type=\"checkbox\" value=\"#{e.id}\" #{checked(e)}/>#{e.title}</label>" for e in result).join('')

    $('#button-clear').on 'click', (event) ->
        e.setMap null for e in fusionTablesLayers
        fusionTablesLayers = []

    $('#button-show').on 'click', (event) ->
        e.setMap null for e in fusionTablesLayers
        fusionTablesLayers = []
        for e in $('#fusion-tables input:checked:lt(5)')
            req = gapi.client.fusiontables.column.list tableId: e.value
            req.execute (result) ->
                if result.error?
                    console.error result.error
                else
                    locations = result.items.filter (e) -> e.type is 'LOCATION'
                    if locations.length > 0
                        option =
                            map: map
                            query:
                                from: e.value
                                select: locations[0].name
                            styles: [
                                    markerOptions:
                                        iconName: 'red_stars'
                                ]
                        fusionTablesLayers.push new google.maps.FusionTablesLayer option
                    else
                        console.error 'no locations'

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
    if localStorage['maps-map-status']?
        mapStatus = JSON.parse localStorage['maps-map-status']
        mapOptions.center = new google.maps.LatLng mapStatus.lat, mapStatus.lng
        mapOptions.zoom = mapStatus.zoom
    else
        mapOptions.center = new google.maps.LatLng 35.660389, 139.729225
        mapOptions.zoom = 14

    map = new google.maps.Map document.getElementById('map'), mapOptions
    map.setTilt 45

# export

window.app =
    tracer: tracer
    initializeDOM: initializeDOM
    initializeGoogleMaps: initializeGoogleMaps
    saveMapStatus: saveMapStatus
    saveOtherStatus: saveOtherStatus
