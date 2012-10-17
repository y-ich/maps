# Google Maps Extensions
# Copyright (C) 2012 ICHIKAWA, Yuji (New 3 Rs)

# custom InfoWindow
class MobileInfoWindow extends google.maps.OverlayView
    constructor: (options) -> @setOptions options

    # accesssors

    getContent: -> @content
    
    getPosition: -> @position
    
    getZIndex: -> @zIndex
    
    setContent: (@content) ->
        unless @element?
            @element = document.createElement 'div'
            @element.style['max-width'] = @maxWidth + 'px' if @maxWidth
            @element.className = 'info-window'
        if typeof @content is 'string'
            @element.innerHTML = @content
        else
            @element.appendChild @content
        google.maps.event.trigger this, 'content_changed'
        
    setPosition: (@position) ->
        google.maps.event.trigger this, 'position_changed'
        
    setZIndex: (@zIndex) ->
        @element.style['z-index'] = @zIndex.toString()
        google.maps.event.trigger this, 'zindex_changed'

    close: -> @setMap null
    
    open: (map, @anchor) ->
        if anchor?
            @setPosition @anchor.getPosition()
            icon = @anchor.getIcon()
            if icon?
                markerSize = icon.size
                markerAnchor = icon.anchor ? new google.maps.Point Math.floor(markerSize.width / 2), markerSize.height
            else
                markerSize = new google.maps.Size DEFAULT_ICON_SIZE, DEFAULT_ICON_SIZE            
                markerAnchor = new google.maps.Point DEFAULT_ICON_SIZE/2, DEFAULT_ICON_SIZE
            @pixelOffset = new google.maps.Size Math.floor(markerSize.width / 2) - markerAnchor.x, - markerAnchor.y, 'px', 'px'            
        @setMap map
        
    setOptions: (options) ->
        @maxWidth = options.maxWidth ? null
        @setContent options.content ? ''
        @disableAutoPan = options.disableAutoPan ? null
        @pixelOffset = options.pixelOffset ? google.maps.Size 0, 0, 'px', 'px'
        @setPosition options.position ? null
        @setZIndex options.zIndex ? 0
        
    # overlayview
    onAdd: ->
        @getPanes().floatPane.appendChild @element
        google.maps.event.trigger this, 'domready'

    draw: ->
        xy = @getProjection().fromLatLngToDivPixel @getPosition()
        @element.style.left = xy.x + @pixelOffset.width - @element.offsetWidth / 2 + 'px'
        @element.style.top = xy.y + @pixelOffset.height - @element.offsetHeight + 'px'

    onRemove: ->
        @element.parentNode.removeChild @element
        @element = null
