# Google Maps Web App
# Copyright (C) 2012-2013 ICHIKAWA, Yuji (New 3 Rs) 

VERSION = '(C) 2012 ICHIKAWA, Yuji (New 3 Rs)<br>Maps ver. 1.2.18'
BLINK_INTERVAL = 500 # ms
STARTUP_TIME = 3000 # ms
timerId = null
$option = $('#option')
$version = $('#version')

# function definitions

# full screen for iPhone
# IMPORTANT: This function should be invoked after initializeDOM for the order of event listener.
fullScreen = ->
    window.scrollTo 0, 0 # hide address bar
    $([document, document.body]).height innerHeight # 100% is not full screen height, is a size below address bar.
    window.addEventListener 'orientationchange', (->
        # scrollTo/scrollLeft will be set beforehand by the other event listener.
        $([document, document.body]).height innerHeight
    ), false
    $('input[type="text"], input[type="search"]').on 'blur', ->
        window.scrollTo document.body.scrollLeft, 0 # I wanted to animate but, animation was flickery on iphone as left always reset to 0 during animation. 


document.write '''
    <div class="startup">
        <div id="logo">RRR</div>
    </div>
    '''
window.applicationCache.addEventListener 'downloading', ->
    timerId = setInterval (-> $option.toggleClass 'btn-light'), BLINK_INTERVAL
    $version.html VERSION + ' (downloading new version...)'
    
window.applicationCache.addEventListener 'cached', ->
    clearInterval timerId
    $option.removeClass 'btn-light' if $option.hasClass 'btn-light'
    $version.html VERSION

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
$version.html VERSION
app.initializeDOM()
fullScreen() if /iPhone/.test(navigator.userAgent) and /Safari/.test(navigator.userAgent)

# post process
window.onpagehide = ->
    app.tracer.stop()
    app.saveMapStatus()
    app.saveOtherStatus()

# finish startup screen
setTimeout (->
    $('.startup').on('webkitTransitionEnd', -> $('.startup').css 'display', 'none')
                 .css 'opacity', '0'
), STARTUP_TIME

app.tracer.start()
