# Google Maps Web App
# Copyright (C) 2012 ICHIKAWA, Yuji (New 3 Rs) 

            
app.initializeGoogleMaps()
app.initializeDOM()
watchPosition = new app.WatchPosition().start()

window.onpagehide = ->
    watchPosition.stop()
    app.saveMapStatus()
    app.saveOtherStatus()
