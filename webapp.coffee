# Google Maps Web App
# Copyright (C) 2012 ICHIKAWA, Yuji (New 3 Rs) 

            
app.initializeGoogleMaps()
app.initializeDOM()
$('#version').html '(C) 2012 ICHIKAWA, Yuji (New 3 Rs)<br>Maps ver. 1.2.1'
app.tracer.start()

window.onpagehide = ->
    app.tracer.stop()
    app.saveMapStatus()
    app.saveOtherStatus()
