# Google Maps Web App
# Copyright (C) 2012-2103 ICHIKAWA, Yuji (New 3 Rs) 

tracer = null

saveMapStatus = ->

saveOtherStatus = ->

getLocalizedString = (key) ->
    if localizedStrings? then localizedStrings[key] ? key else key

setLocalExpressionInto = (id, english) ->
    el = document.getElementById id
    el.lastChild.data = getLocalizedString english if el?

localize = ->
    idWordPairs =
        'replace-pin' : 'Replace Pin'
        'print' : 'Print'
        'traffic' : 'Show Traffic'
        'panoramio' : 'Show Panoramio'
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
        'remove-pin' : 'Remove Pin'
        'add-into-contact' : 'Add to Contacts'
        'send-place' : 'Share Location'
        'add-bookmark' : 'Add to Bookmarks'
        'add-bookmark-message' : 'Type a name for the bookmark'
        'cancel-add-bookmark' : 'Cancel'
        'add-bookmark-title' : 'Add Bookmark'
        'save-bookmark' : 'Save'
        'edit3' : 'Edit'
        'directions-title' : 'Directions'

    document.title = getLocalizedString 'Maps'
    # document.getElementById('search-input').placeholder = getLocalizedString 'Search or Address'
    setLocalExpressionInto key, value for key, value of idWordPairs

initializeDOM = ->
    localize()
    $('#container').css 'display', ''

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
