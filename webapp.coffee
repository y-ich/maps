# Google Maps Web App
# Copyright (C) 2012 ICHIKAWA, Yuji (New 3 Rs) 

            
app.initializeGoogleMaps()
app.initializeDOM()
watchPosition = new app.WatchPosition().start app.traceHandler
    , (error) -> console.log error.message
    ,
        enableHighAccuracy: true
        timeout: 30000

window.onpagehide = ->
    watchPosition.stop()
    app.saveMapStatus()
    app.saveOtherStatus()
