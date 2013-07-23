// Generated by CoffeeScript 1.6.1
(function() {
  var $map, autocomplete, destination, directionsRenderer, home, map, navigationMode, normalMap, rotationMap, route, say, startWatch, watchId;

  map = null;

  home = new google.maps.LatLng(34.584305, 135.83521);

  destination = new google.maps.LatLng(34.529284, 135.797228);

  $map = $('#map');

  directionsRenderer = null;

  watchId = null;

  navigationMode = false;

  route = function(origin, destination, callback) {
    if (callback == null) {
      callback = function() {};
    }
    return route.service.route({
      avoidHighways: true,
      avoidTolls: true,
      destination: destination,
      origin: origin,
      provideRouteAlternatives: true,
      travelMode: google.maps.TravelMode.DRIVING
    }, function(result, status) {
      if (status === google.maps.DirectionsStatus.OK) {
        directionsRenderer = new google.maps.DirectionsRenderer({
          directions: result,
          map: map,
          panel: $('#panel')[0],
          routeIndex: 0
        });
        return callback(result);
      } else {
        return alert(status);
      }
    });
  };

  route.service = new google.maps.DirectionsService();

  rotationMap = function() {
    var r;
    r = Math.ceil(Math.sqrt(innerWidth * innerWidth + innerHeight * innerHeight));
    $map.css('width', r + 'px');
    $map.css('height', r + 'px');
    $map.css('left', -(r - innerWidth) / 2 + 'px');
    $map.css('top', -(r - innerHeight) / 2 + 'px');
    return google.maps.event.trigger(map, 'resize');
  };

  normalMap = function() {
    $map.css('width', '');
    $map.css('height', '');
    $map.css('left', '');
    $map.css('top', '');
    $map.css('-webkitTransform', '');
    $map.css('display', '');
    return google.maps.event.trigger(map, 'resize');
  };

  say = function(str) {
    return $('#audio').attr('src', "http://translate.google.com/translate_tts?tl=ja&q=" + (encodeURIComponent(str)));
  };

  startWatch = function() {
    rotationMap();
    map.setZoom(18);
    return watchId = navigator.geolocation.watchPosition((function(position) {
      var latLng, leg, step, _i, _len, _ref, _results;
      latLng = new google.maps.LatLng(position.coords.latitude, position.coords.longitude);
      map.setCenter(latLng);
      new google.maps.StreetViewService().getPanoramaByLocation(latLng, 49, function(data, status) {
        var sv;
        if (status === google.maps.StreetViewStatus.OK) {
          sv = map.getStreetView();
          sv.setPosition(data.location.latLng);
          return $map.css('display', 'none');
        } else {
          return $map.css('display', '');
        }
      });
      _ref = directionsRenderer.getDirections().routes[directionsRenderer.getRouteIndex()].legs;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        leg = _ref[_i];
        _results.push((function() {
          var _j, _len1, _ref1, _results1;
          _ref1 = leg.steps;
          _results1 = [];
          for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
            step = _ref1[_j];
            if (google.maps.geometry.spherical.computeDistanceBetween(latLng, step.start_location) < 50) {
              if (step.passed == null) {
                say(step.instructions);
                _results1.push(step.passed = true);
              } else {
                _results1.push(void 0);
              }
            } else {
              _results1.push(void 0);
            }
          }
          return _results1;
        })());
      }
      return _results;
    }), (function() {}), {
      enableHighAccuracy: true,
      timeout: 60000
    });
  };

  window.ondeviceorientation = function(event) {
    if (watchId != null) {
      map.getStreetView().setPov({
        heading: event.webkitCompassHeading,
        pitch: 0
      });
      return $map.css('-webkitTransform', "rotate(" + (-event.webkitCompassHeading) + "deg)");
    }
  };

  window.onpagehide = function() {
    if (watchId != null) {
      return navigator.geolocation.clearWatch(watchId);
    }
  };

  window.onpageshow = function() {
    if (watchId != null) {
      return startWatch();
    }
  };

  autocomplete = new google.maps.places.Autocomplete($('#search > form > input')[0]);

  google.maps.event.addListener(autocomplete, 'place_changed', function() {
    var place;
    place = autocomplete.getPlace();
    if (place.geometry != null) {
      return route(home, place.geometry.location, function() {
        return $('#start').removeAttr('disabled');
      });
    }
  });

  $('#search form').on('submit', function(event) {
    return event.preventDefault();
  });

  $('#start').on('click', function(event) {
    $('#panel').css('display', 'none');
    return startWatch();
  });

  navigator.geolocation.getCurrentPosition((function(position) {
    return map = new google.maps.Map($map[0], {
      center: new google.maps.LatLng(position.coords.latitude, position.coords.longitude),
      zoom: 14,
      mapTypeId: google.maps.MapTypeId.ROADMAP,
      streetView: new google.maps.StreetViewPanorama($('#street-view')[0], {
        visible: true
      })
    });
  }));

}).call(this);
