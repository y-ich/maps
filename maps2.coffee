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

    $('#modal-fusion-tables').on 'show', (event) ->
        $('#fusion-tables').empty()
        searchFiles 'mimeType = "application/vnd.google-apps.fusiontable"', (result) ->
            $('#fusion-tables').html ("<label><input type=\"checkbox\" value=\"#{e.id}\" />#{e.title}</label>" for e in result).join('')

    $('#button-clear').on 'click', (event) ->
        e.setMap null for e in fusionTablesLayers
        fusionTablesLayers = []

    $('#button-show').on 'click', (event) ->
        e.setMap null for e in fusionTablesLayers
        fusionTablesLayers = []
        for e in $('#fusion-tables input:checked:lt(5)')
            console.log e
            req = gapi.client.fusiontables.column.list tableId: e.value
            req.execute (result) ->
                if result.error?
                    console.error result.error
                else
                    option =
                        map: map
                        query:
                            from: e.value
                        styles: [
                                markerOptions:
                                    iconName: 'red_stars'
                            ]
                    locations = result.items.filter (e) -> e.type is 'LOCATION'
                    console.log locations
                    option.query.select = '場所' #locations[0].name
                    fusionTablesLayers.push new google.maps.FusionTablesLayer option

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
