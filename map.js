// Generated by CoffeeScript 1.3.3
(function() {
  var $destination, $origin, directionsRenderer, directionsService, geocoder, initializeDOM, initializeGoogleMaps, map, meterToString, naviMarker, navigate, pulsatingMarker, saveStatus, searchDirections, secondToString, traceHandler, traceHeadingEnable, travelMode, watchId;

  watchId = null;

  traceHeadingEnable = false;

  geocoder = null;

  map = null;

  pulsatingMarker = null;

  naviMarker = null;

  directionsService = null;

  directionsRenderer = null;

  $origin = $('#origin');

  $destination = $('#destination');

  travelMode = function() {
    return google.maps.TravelMode[$('#travel-mode').children('.btn-primary').attr('id').toUpperCase()];
  };

  secondToString = function(sec) {
    var day, hour, min, result;
    result = '';
    min = Math.floor(sec / 60);
    sec -= min * 60;
    hour = Math.floor(min / 60);
    min -= hour * 60;
    day = Math.floor(hour / 24);
    hour -= day * 24;
    if (day > 0) {
      result += day + '日';
    }
    if (hour > 0 && day < 10) {
      result += hour + '時間';
    }
    if (min > 0 && day === 0 && hour < 10) {
      result += min + '分';
    }
    return result;
  };

  meterToString = function(meter) {
    var km, result;
    result = '';
    km = Math.floor(meter / 1000);
    meter -= km * 1000;
    if (km > 0) {
      result += km + 'km';
    }
    if (meter > 0 && km < 10) {
      result += meter + 'm';
    }
    return result;
  };

  searchDirections = function() {
    return directionsService.route({
      destination: $('#destination').val(),
      origin: $('#origin').val(),
      travelMode: travelMode()
    }, function(result, status) {
      var distance, duration;
      window.result = result;
      switch (status) {
        case google.maps.DirectionsStatus.OK:
          directionsRenderer.setMap(map);
          directionsRenderer.setDirections(result);
          switch (travelMode()) {
            case google.maps.TravelMode.WALKING:
              distance = (result.routes[0].legs.map(function(e) {
                return e.distance.value;
              })).reduce(function(a, b) {
                return a + b;
              });
              duration = (result.routes[0].legs.map(function(e) {
                return e.duration.value;
              })).reduce(function(a, b) {
                return a + b;
              });
              return $('#message').html("" + (secondToString(duration)) + "〜" + (meterToString(distance)) + "〜" + result.routes[0].summary);
            case google.maps.TravelMode.DRIVING:
              distance = (result.routes[0].legs.map(function(e) {
                return e.distance.value;
              })).reduce(function(a, b) {
                return a + b;
              });
              duration = (result.routes[0].legs.map(function(e) {
                return e.duration.value;
              })).reduce(function(a, b) {
                return a + b;
              });
              return $('#message').html("" + result.routes[0].summary + "<br>" + (secondToString(duration)) + "〜" + (meterToString(distance)));
          }
          break;
        case google.maps.DirectionsStatus.ZERO_RESULTS:
          directionsRenderer.setMap(null);
          return $('#message').html("見つかりませんでした。");
        default:
          directionsRenderer.setMap(null);
          return console.log(status);
      }
    });
  };

  saveStatus = function() {
    var pos;
    pos = map.getCenter();
    return localStorage['last'] = JSON.stringify({
      lat: pos.lat(),
      lng: pos.lng(),
      zoom: map.getZoom(),
      origin: $origin.val(),
      destination: $destination.val()
    });
  };

  navigate = function(str) {
    var lengths, route, step, steps, _ref;
    route = (_ref = directionsRenderer.getDirections()) != null ? _ref.routes[directionsRenderer.getRouteIndex()] : void 0;
    if (route == null) {
      return;
    }
    switch (str) {
      case 'start':
        navigate.leg = 0;
        navigate.step = 0;
        $('#navi-toolbar2').css('display', 'block');
        naviMarker.setVisible(true);
        break;
      case 'next':
        if (navigate.step < route.legs[navigate.leg].steps.length - 1) {
          navigate.step += 1;
        } else if (navigate.leg < route.legs.length - 1) {
          navigate.leg += 1;
          navigate.step = 0;
        }
        break;
      case 'previous':
        if (navigate.step > 0) {
          navigate.step -= 1;
        } else if (navigate.leg > 0) {
          navigate.leg -= 1;
          navigate.step = route.legs[navigate.leg].steps.legth - 1;
        }
    }
    map.setZoom(15);
    step = route.legs[navigate.leg].steps[navigate.step];
    naviMarker.setPosition(step.start_location);
    map.setCenter(step.start_location);
    lengths = route.legs.map(function(e) {
      return e.steps.length;
    });
    steps = navigate.leg === 0 ? navigate.step : lengths.slice(0, navigate.leg).reduce(function(a, b) {
      return a + b;
    });
    $('#numbering').text((steps + 1) + '/' + (route.legs.map(function(e) {
      return e.steps.length;
    })).reduce(function(a, b) {
      return a + b;
    }));
    return $('#message').html(step.instructions);
  };

  navigate.leg = null;

  navigate.step = null;

  initializeGoogleMaps = function() {
    var destinationMarker, droppedMarker, getLocationHandler, last, mapOptions, startMarker;
    mapOptions = {
      mapTypeId: google.maps.MapTypeId.ROADMAP,
      disableDefaultUI: true
    };
    if (localStorage['last'] != null) {
      last = JSON.parse(localStorage['last']);
      mapOptions.center = new google.maps.LatLng(last.lat, last.lng);
      mapOptions.zoom = last.zoom;
    } else {
      mapOptions.center = new google.maps.LatLng(35.660389, 139.729225);
      mapOptions.zoom = 14;
    }
    geocoder = new google.maps.Geocoder();
    map = new google.maps.Map(document.getElementById("map"), mapOptions);
    directionsService = new google.maps.DirectionsService();
    directionsRenderer = new google.maps.DirectionsRenderer();
    directionsRenderer.setMap(map);
    google.maps.event.addListener(directionsRenderer, 'directions_changed', function() {
      navigate.leg = null;
      navigate.step = null;
      $('#navi-toolbar2').css('display', 'none');
      return naviMarker.setVisible(false);
    });
    droppedMarker = new google.maps.Marker({
      map: map,
      position: mapOptions.center,
      title: 'ドロップされたピン',
      visible: false
    });
    startMarker = null;
    destinationMarker = null;
    naviMarker = new google.maps.Marker({
      flat: true,
      icon: new google.maps.MarkerImage('img/bluedot.png', null, null, new google.maps.Point(8, 8), new google.maps.Size(17, 17)),
      map: map,
      optimized: false,
      visible: false
    });
    google.maps.event.addListener(map, 'click', function(event) {
      droppedMarker.setVisible(true);
      return droppedMarker.setPosition(event.latLng);
    });
    google.maps.event.addListener(map, 'center_changed', saveStatus);
    google.maps.event.addListener(map, 'zoom_changed', saveStatus);
    getLocationHandler = function(data, status) {
      var sv, _ref;
      switch (status) {
        case google.maps.StreetViewStatus.OK:
          sv = map.getStreetView();
          sv.setPosition(data.location.latLng);
          droppedMarker.setPosition(data.location.latLng);
          sv.setPov({
            heading: (_ref = map.getHeading()) != null ? _ref : 0,
            pitch: 0,
            zoom: 1
          });
          return sv.setVisible(true);
        case google.maps.StreetViewStatus.ZERO_RESULTS:
          return alert("近くにストリートビューが見つかりませんでした。");
        default:
          return alert("すいません、エラーが起こりました。");
      }
    };
    return google.maps.event.addListener(droppedMarker, 'click', function(event) {
      return new google.maps.StreetViewService().getPanoramaByLocation(droppedMarker.getPosition(), 49, getLocationHandler);
    });
  };

  traceHandler = function(position) {
    var latLng, transform;
    latLng = new google.maps.LatLng(position.coords.latitude, position.coords.longitude);
    if (pulsatingMarker) {
      pulsatingMarker.setPosition(latLng);
    } else {
      pulsatingMarker = new google.maps.Marker({
        flat: true,
        icon: new google.maps.MarkerImage('img/bluedot.png', null, null, new google.maps.Point(8, 8), new google.maps.Size(17, 17)),
        map: map,
        optimized: false,
        position: latLng,
        title: 'I might be here',
        visible: true
      });
    }
    map.setCenter(latLng);
    if (traceHeadingEnable && (position.coords.heading != null)) {
      transform = $map.css('-webkit-transform');
      if (/rotate(-?[\d.]+deg)/.test(transform)) {
        transform = transform.replace(/rotate(-?[\d.]+deg)/, "rotate(" + (-position.coords.heading) + "deg)");
      } else {
        transform = transform + (" rotate(" + (-position.coords.heading) + "deg)");
      }
      return $map.css('-webkit-transform', transform);
    }
  };

  initializeDOM = function() {
    var $edit, $gps, $map, $navi, $route, $routeSearchFrame, $search, $travelMode, $versatile, last;
    $(document.body).css('padding-top', $('#header').outerHeight(true));
    if (localStorage['last'] != null) {
      last = JSON.parse(localStorage['last']);
      if (last.origin != null) {
        $('#origin').val(last.origin);
      }
      if (last.destination != null) {
        $('#destination').val(last.destination);
      }
    }
    $map = $('#map');
    $map.height(innerHeight - $('#header').outerHeight(true) - $('#footer').outerHeight(true));
    $gps = $('#gps');
    $gps.data('status', 'normal');
    $gps.on('click', function() {
      switch ($gps.data('status')) {
        case 'normal':
          $gps.data('status', 'trace-position');
          $gps.addClass('btn-primary');
          traceHeadingEnable = false;
          return watchId = navigator.geolocation.watchPosition(traceHandler, function(error) {
            return console.log(error.message);
          }, {
            enableHighAccuracy: true,
            timeout: 30000
          });
        case 'trace-position':
          navigator.geolocation.clearWatch(watchId);
          watchId = null;
          $gps.data('status', 'normal');
          $map.css('-webkit-transform', $map.css('-webkit-transform').replace(/\s*rotate(-?[\d.]+deg)/, ''));
          $gps.removeClass('btn-primary');
          $gps.children('i').removeClass('icon-hand-up');
          return $gps.children('i').addClass('icon-globe');
      }
    });
    $('#address').on('change', function() {
      return geocoder.geocode({
        address: this.value
      }, function(result, status) {
        if (status === google.maps.GeocoderStatus.OK) {
          return map.setCenter(result[0].geometry.location);
        } else {
          return alert(status);
        }
      });
    });
    $navi = $('#navi');
    $search = $('#search');
    $search.on('click', function() {
      directionsRenderer.setMap(null);
      naviMarker.setVisible(false);
      $route.removeClass('btn-primary');
      $search.addClass('btn-primary');
      return $navi.toggle();
    });
    $route = $('#route');
    $route.on('click', function() {
      $search.removeClass('btn-primary');
      $route.addClass('btn-primary');
      $navi.toggle();
      return directionsRenderer.setMap(map);
    });
    $edit = $('#edit');
    $versatile = $('#versatile');
    $routeSearchFrame = $('#route-search-frame');
    $edit.on('click', function() {
      if ($edit.text() === '編集') {
        $edit.text('キャンセル');
        $versatile.text('経路');
        $('#navi-toolbar2').css('display', 'none');
        return $routeSearchFrame.css('top', '0px');
      } else {
        $edit.text('編集');
        $versatile.text('出発');
        if ((navigate.leg != null) && (navigate.step != null)) {
          $('#navi-toolbar2').css('display', 'block');
        }
        return $routeSearchFrame.css('top', '');
      }
    });
    $('#edit2').on('click', function() {
      return $edit.trigger('click');
    });
    $('#switch').on('click', function() {
      var tmp;
      tmp = $('#destination').val();
      $('#destination').val($('#origin').val());
      $('#origin').val(tmp);
      return saveStatus();
    });
    $('#origin, #destination').on('changed', saveStatus);
    $travelMode = $('#travel-mode');
    $travelMode.children(':not(#transit)').on('click', function() {
      var $this;
      $this = $(this);
      if ($this.hasClass('btn-primary')) {
        return;
      }
      $travelMode.children().removeClass('btn-primary');
      $this.addClass('btn-primary');
      return searchDirections();
    });
    $versatile.on('click', function() {
      switch ($versatile.text()) {
        case '経路':
          $edit.text('編集');
          $versatile.text('出発');
          $routeSearchFrame.css('top', '');
          return searchDirections();
        case '出発':
          return navigate('start');
      }
    });
    $('#cursor-left').on('click', function() {
      return navigate('previous');
    });
    $('#cursor-right').on('click', function() {
      return navigate('next');
    });
    return window.onpagehide = function() {
      if (!watchId) {
        navigator.geolocation.clearWatch(watchId);
      }
      return saveStatus();
    };
  };

  initializeGoogleMaps();

  initializeDOM();

}).call(this);
