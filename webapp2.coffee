# Google Maps Web App
# Copyright (C) 2012-2013 ICHIKAWA, Yuji (New 3 Rs) 

VERSION = '(C) 2013 ICHIKAWA, Yuji (New 3 Rs)<br>Maps ver. 2.0.0'

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

$(->
    app.initialize ->
        $('.startup').on($.support.transition.end, -> $(this).css 'display', 'none')
                     .addClass 'fade'
)
# fullScreen() if /iPhone/.test(navigator.userAgent) and /Safari/.test(navigator.userAgent)

window.onpagehide = app.saveMapStatus
