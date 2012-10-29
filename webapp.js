// Generated by CoffeeScript 1.3.3
(function() {
  var type, types, _i, _len;

  types = ['checking', 'noupdate', 'downloading', 'progress', 'cached', 'updateready', 'obsolete', 'error'];

  for (_i = 0, _len = types.length; _i < _len; _i++) {
    type = types[_i];
    window.applicationCache.addEventListener(type, function(event) {
      return console.log(event.type);
    });
  }

  app.initializeGoogleMaps();

  app.initializeDOM();

  $('#version').html('(C) 2012 ICHIKAWA, Yuji (New 3 Rs)<br>Maps ver. 1.2.5');

  window.onpagehide = function() {
    app.tracer.stop();
    app.saveMapStatus();
    return app.saveOtherStatus();
  };

  app.tracer.start();

}).call(this);
