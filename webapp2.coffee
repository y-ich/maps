# Google Maps Web App
# Copyright (C) 2012-2013 ICHIKAWA, Yuji (New 3 Rs) 

VERSION = '(C) 2013 ICHIKAWA, Yuji (New 3 Rs)<br>Maps ver. 2.0.0'
STARTUP_TIME = 2000 # ms

# function definitions

# full screen for iPhone
# IMPORTANT: This function should be invoked after app.initialize for the order of event listener.
fullScreen = ->
    $body = $(document.body)
    $dummy = $("<div id=\"dummy\" style=\"position: absolute; width: 100%; height: #{screen.availHeight}px; top: 0px\"></div>")
    $body.append $dummy
    window.addEventListener 'orientationchange', (->
        # scrollTo/scrollLeft will be set beforehand by the other event listener.
        $([document, document.body]).height innerHeight
    ), false
    $('input[type="text"], input[type="search"]').on 'blur', ->
        window.scrollTo document.body.scrollLeft, 0 # I wanted to animate but, animation was flickery on iphone as left always reset to 0 during animation. 
    setTimeout (->
        window.scrollTo 0, 0 # hide address bar
        $([document, document.body]).height innerHeight # 100% is not full screen height, is a size below address bar.
        $dummy.remove()
    ), 0

# startup screen for on-browser
document.write """
    <div class="startup">
        <div id="logo">RRR</div>
    </div>
    """

# application cache debug information            
types = ['checking', 'noupdate', 'downloading', 'progress','cached', 'updateready', 'obsolete', 'error']
for type in types
    applicationCache.addEventListener type, (event) -> console.log 'cache', event.type

app.initialize()
fullScreen() if /iPhone/.test(navigator.userAgent) and /Safari/.test(navigator.userAgent)

window.onpagehide = app.saveMapStatus

# finish startup screen
if /WebKit/.test navigator.userAgent
    setTimeout (->
        $('.startup').on('webkitTransitionEnd', -> $('.startup').css 'display', 'none')
                     .css 'opacity', '0'
    ), STARTUP_TIME
else
    $('.startup').css 'display', 'none'