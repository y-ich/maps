# Google Maps Web App
# Copyright (C) 2012 ICHIKAWA, Yuji (New 3 Rs) 


# application cache debug information            
types = ['checking', 'noupdate', 'downloading', 'progress','cached', 'updateready', 'obsolete', 'error']
for type in types
    window.applicationCache.addEventListener type, (event) -> console.log event.type

app.initializeGoogleMaps()
app.initializeDOM()
$('#version').html '(C) 2012 ICHIKAWA, Yuji (New 3 Rs)<br>Maps ver. 1.2.5'

window.onpagehide = ->
    app.tracer.stop()
    app.saveMapStatus()
    app.saveOtherStatus()

app.tracer.start()
