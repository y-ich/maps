# Google Maps Web App
# Copyright (C) 2012 ICHIKAWA, Yuji (New 3 Rs) 

VERSION = '(C) 2012 ICHIKAWA, Yuji (New 3 Rs)<br>Maps ver. 1.2.12'
BLINK_INTERVAL = 500 # ms
timerId = null
$option = $('#option')
$version = $('#version')

window.applicationCache.addEventListener 'downloading', ->
    timerId = setInterval (-> $option.toggleClass 'btn-light'), BLINK_INTERVAL
    $version.html VERSION + ' (downloading new version...)'
    
window.applicationCache.addEventListener 'cached', ->
    clearInterval timerId
    $option.removeClass 'btn-light' if $option.hasClass 'btn-light'

window.applicationCache.addEventListener 'updateready', ->
    clearInterval timerId
    $option.addClass 'btn-light' unless $option.hasClass 'btn-light'
    $version.html VERSION + ' (new version available)'

window.applicationCache.addEventListener 'error', ->
    clearInterval timerId
    $option.addClass 'btn-light' unless $option.hasClass 'btn-light'
    $version.html VERSION + ' (cache error)'
    
# application cache debug information            
types = ['checking', 'noupdate', 'downloading', 'progress','cached', 'updateready', 'obsolete', 'error']
for type in types
    window.applicationCache.addEventListener type, (event) -> console.log event.type

app.initializeGoogleMaps()
app.initializeDOM()
$version.html VERSION

window.onpagehide = ->
    app.tracer.stop()
    app.saveMapStatus()
    app.saveOtherStatus()

app.tracer.start()
