// Generated by CoffeeScript 1.4.0
(function() {
  var $option, $version, BLINK_INTERVAL, VERSION, timerId, type, types, _i, _len;

  VERSION = '(C) 2012 ICHIKAWA, Yuji (New 3 Rs)<br>Maps ver. 1.2.12';

  BLINK_INTERVAL = 500;

  timerId = null;

  $option = $('#option');

  $version = $('#version');

  window.applicationCache.addEventListener('downloading', function() {
    timerId = setInterval((function() {
      return $option.toggleClass('btn-light');
    }), BLINK_INTERVAL);
    return $version.html(VERSION + ' (downloading new version...)');
  });

  window.applicationCache.addEventListener('cached', function() {
    clearInterval(timerId);
    if ($option.hasClass('btn-light')) {
      return $option.removeClass('btn-light');
    }
  });

  window.applicationCache.addEventListener('updateready', function() {
    clearInterval(timerId);
    if (!$option.hasClass('btn-light')) {
      $option.addClass('btn-light');
    }
    return $version.html(VERSION + ' (new version available)');
  });

  window.applicationCache.addEventListener('error', function() {
    clearInterval(timerId);
    if (!$option.hasClass('btn-light')) {
      $option.addClass('btn-light');
    }
    return $version.html(VERSION + ' (cache error)');
  });

  types = ['checking', 'noupdate', 'downloading', 'progress', 'cached', 'updateready', 'obsolete', 'error'];

  for (_i = 0, _len = types.length; _i < _len; _i++) {
    type = types[_i];
    window.applicationCache.addEventListener(type, function(event) {
      return console.log(event.type);
    });
  }

  app.initializeGoogleMaps();

  app.initializeDOM();

  $version.html(VERSION);

  window.onpagehide = function() {
    app.tracer.stop();
    app.saveMapStatus();
    return app.saveOtherStatus();
  };

  app.tracer.start();

}).call(this);
