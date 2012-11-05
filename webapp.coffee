# Google Maps Web App
# Copyright (C) 2012 ICHIKAWA, Yuji (New 3 Rs) 


# application cache debug information            
types = ['checking', 'noupdate', 'downloading', 'progress','cached', 'updateready', 'obsolete', 'error']
for type in types
    window.applicationCache.addEventListener type, (event) -> console.log event.type

id = null
$option = $('#option')

window.applicationCache.addEventListener 'downloading', ->
    id = setInterval (-> $('#option').toggleClass 'btn-light'), 500
    
window.applicationCache.addEventListener 'cached', ->
    clearInterval id
    $option.removeClass 'btn-light' if $option.hasClass 'btn-light'

window.applicationCache.addEventListener 'updateready', ->
    clearInterval id
    $option.addClass 'btn-light' unless $option.hasClass 'btn-light'
    $('#version').html $('#version').html() + ' (new version available)'

window.applicationCache.addEventListener 'error', ->
    clearInterval id
    $option.addClass 'btn-light' unless $option.hasClass 'btn-light'
    $('#version').html $('#version').html() + ' (cache error)'
    
app.initializeGoogleMaps()
app.initializeDOM()
$('#version').html '(C) 2012 ICHIKAWA, Yuji (New 3 Rs)<br>Maps ver. 1.2.9'

window.onpagehide = ->
    app.tracer.stop()
    app.saveMapStatus()
    app.saveOtherStatus()

app.tracer.start()
