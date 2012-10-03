// Generated by CoffeeScript 1.3.3
(function() {
  var $destination, $gps, $map, $origin, MapFSM, MapState, bookmarkContext, directionsRenderer, droppedInfo, droppedMarker, geocodeHandler, geocoder, getLocationHandler, getMapType, getTravelMode, initializeDOM, initializeGoogleMaps, makeInfoMessage, map, mapFSM, mapSum, meterToString, method, name, naviMarker, navigate, pulsatingMarker, saveStatus, searchDirections, secondToString, traceHandler, traceState, _ref;

  map = null;

  traceState = 'normal';

  geocoder = null;

  pulsatingMarker = null;

  droppedMarker = null;

  droppedInfo = null;

  naviMarker = null;

  directionsRenderer = null;

  $map = null;

  $gps = null;

  $origin = $('#origin');

  $destination = $('#destination');

  bookmarkContext = 'address';

  MapState = (function() {

    function MapState(name) {
      this.name = name;
    }

    MapState.prototype.update = function() {
      return this;
    };

    MapState.prototype.gpsClicked = function() {
      return this;
    };

    MapState.prototype.moved = function() {
      return this;
    };

    MapState.prototype.bookmarkClicked = function() {
      return this;
    };

    MapState.prototype.currentPositionClicked = function() {
      return this;
    };

    MapState.NORMAL = new MapState('normal');

    MapState.TRACE_POSITION = new MapState('trace_position');

    MapState.TRACE_HEADING = new MapState('trace_heading');

    return MapState;

  })();

  MapState.NORMAL.update = function() {
    if (traceHandler.id != null) {
      navigator.geolocation.clearWatch(traceHandler.id);
    }
    traceHandler.id = null;
    $map.css('-webkit-transform', $map.css('-webkit-transform').replace(/\s*rotate(-?[\d.]+deg)/, ''));
    $gps.removeClass('btn-primary');
    return this;
  };

  MapState.NORMAL.gpsClicked = function() {
    return MapState.TRACE_POSITION;
  };

  MapState.NORMAL.currentPositionClicked = function() {
    return MapState.TRACE_POSITION;
  };

  MapState.TRACE_POSITION.update = function() {
    $gps.addClass('btn-primary');
    traceHandler.heading = false;
    traceHandler.id = navigator.geolocation.watchPosition(traceHandler, function(error) {
      return console.log(error.message);
    }, {
      enableHighAccuracy: true,
      timeout: 30000
    });
    return this;
  };

  MapState.TRACE_POSITION.gpsClicked = function() {
    return MapState.NORMAL;
  };

  MapState.TRACE_POSITION.moved = function() {
    return MapState.NORMAL;
  };

  MapState.TRACE_HEADING.update = function() {
    traceHandler.heading = true;
    return this;
  };

  MapState.TRACE_HEADING.gpsClicked = function() {
    return MapState.NORMAL;
  };

  MapState.TRACE_HEADING.moved = function() {
    return MapState.NORMAL;
  };

  MapState.TRACE_HEADING.bookmarkClicked = function() {
    return MapState.TRACE_POSITION;
  };

  MapFSM = (function() {

    function MapFSM(state) {
      this.state = state;
    }

    MapFSM.prototype.setState = function(state) {
      if (this.state === state) {
        return;
      }
      this.state = state;
      return this.state.update();
    };

    return MapFSM;

  })();

  _ref = MapState.prototype;
  for (name in _ref) {
    method = _ref[name];
    if (typeof method === 'function') {
      MapFSM.prototype[name] = (function(name) {
        return function() {
          return this.setState(this.state[name]());
        };
      })(name);
    }
  }

  mapFSM = new MapFSM(MapState.NORMAL);

  mapSum = function(array, fn) {
    return array.map(fn).reduce(function(a, b) {
      return a + b;
    });
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
    if (meter < 1000) {
      return meter + 'm';
    } else {
      return parseFloat((meter / 1000).toPrecision(2)) + 'km';
    }
  };

  getTravelMode = function() {
    return google.maps.TravelMode[$('#travel-mode').children('.btn-primary').attr('id').toUpperCase()];
  };

  getMapType = function() {
    return google.maps.MapTypeId[$('#map-type').children('.btn-primary').attr('id').toUpperCase()];
  };

  makeInfoMessage = function(message) {
    return "<table id=\"info-window\"><tr>\n    <td><button id=\"street-view\" class=\"btn\"><i class=\"icon-user\"></i></button></td>\n    <td style=\"white-space: nowrap;\"><div>ドロップされたピン<br><span id=\"dropped-message\" style=\"font-size:10px\">" + message + "</span></div></td>\n    <td><button id=\"info\" class\"btn disabled\"><i class=\"icon-chevron-right\"></i></button></td>\n</tr></table>";
  };

  searchDirections = function() {
    return searchDirections.service.route({
      destination: $('#destination').val(),
      origin: $('#origin').val(),
      provideRouteAlternatives: getTravelMode() !== google.maps.TravelMode.WALKING,
      travelMode: getTravelMode()
    }, function(result, status) {
      var $message, distance, duration, index, message, summary;
      $message = $('#message');
      message = '';
      window.result = result;
      switch (status) {
        case google.maps.DirectionsStatus.OK:
          directionsRenderer.setMap(map);
          directionsRenderer.setDirections(result);
          index = directionsRenderer.getRouteIndex();
          if (result.routes.length > 1) {
            message += "候補経路：全" + result.routes.length + "件中" + (index + 1) + "件目<br>";
          }
          distance = mapSum(result.routes[index].legs, function(e) {
            return e.distance.value;
          });
          duration = mapSum(result.routes[index].legs, function(e) {
            return e.duration.value;
          });
          summary = "" + (secondToString(duration)) + "〜" + (meterToString(distance)) + "〜" + result.routes[index].summary;
          if (summary.length > innerWidth / parseInt($message.css('font-size'))) {
            summary = "" + result.routes[index].summary + "<br>" + (secondToString(duration)) + "〜" + (meterToString(distance));
          }
          message += summary;
          return $('#message').html(message);
        case google.maps.DirectionsStatus.ZERO_RESULTS:
          directionsRenderer.setMap(null);
          return $('#message').html("経路が見つかりませんでした。");
        default:
          directionsRenderer.setMap(null);
          return console.log(status);
      }
    });
  };

  searchDirections.service = new google.maps.DirectionsService();

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
    var lengths, route, step, steps, _ref1;
    route = (_ref1 = directionsRenderer.getDirections()) != null ? _ref1.routes[directionsRenderer.getRouteIndex()] : void 0;
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

  geocodeHandler = function() {
    if (this.value === '') {
      return;
    }
    return geocoder.geocode({
      address: this.value
    }, function(result, status) {
      if (status === google.maps.GeocoderStatus.OK) {
        return map.setCenter(result[0].geometry.location);
      } else {
        return alert(status);
      }
    });
  };

  getLocationHandler = function(data, status) {
    var sv, _ref1;
    switch (status) {
      case google.maps.StreetViewStatus.OK:
        sv = map.getStreetView();
        sv.setPosition(data.location.latLng);
        droppedMarker.setPosition(data.location.latLng);
        sv.setPov({
          heading: (_ref1 = map.getHeading()) != null ? _ref1 : 0,
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
    if (traceHandler.heading && (position.coords.heading != null)) {
      transform = $map.css('-webkit-transform');
      if (/rotate(-?[\d.]+deg)/.test(transform)) {
        transform = transform.replace(/rotate(-?[\d.]+deg)/, "rotate(" + (-position.coords.heading) + "deg)");
      } else {
        transform = transform + (" rotate(" + (-position.coords.heading) + "deg)");
      }
      return $map.css('-webkit-transform', transform);
    }
  };

  traceHandler.heading = false;

  traceHandler.id = null;

  initializeGoogleMaps = function() {
    var destinationMarker, last, mapOptions, startMarker;
    mapOptions = {
      mapTypeId: getMapType(),
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
    map = new google.maps.Map(document.getElementById("map"), mapOptions);
    geocoder = new google.maps.Geocoder();
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
    droppedInfo = new google.maps.InfoWindow({
      disableAutoPan: true,
      maxWidth: innerWidth
    });
    droppedInfo.open(map, droppedMarker);
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
      droppedMarker.setPosition(event.latLng);
      droppedInfo.setContent(makeInfoMessage(''));
      return geocoder.geocode({
        latLng: event.latLng
      }, function(result, status) {
        var message;
        message = status === google.maps.GeocoderStatus.OK ? result[0].formatted_address.replace(/日本, /, '').replace(/.*〒[\d-]+/, '') : 'ドロップされたピン</br>情報がみつかりませんでした。';
        return droppedInfo.setContent(makeInfoMessage(message));
      });
    });
    google.maps.event.addListener(map, 'dragstart', function() {
      return mapFSM.moved();
    });
    google.maps.event.addListener(map, 'center_changed', saveStatus);
    return google.maps.event.addListener(map, 'zoom_changed', saveStatus);
  };

  initializeDOM = function() {
    var $edit, $mapType, $navi, $option, $route, $routeSearchFrame, $search, $traffic, $travelMode, $versatile, backToMap, last, trafficLayer;
    document.addEventListener('touchmove', function(event) {
      return event.preventDefault();
    });
    $('#pin-list-frame').on('touchmove', function(event) {
      return event.stopPropagation();
    });
    if (localStorage['last'] != null) {
      last = JSON.parse(localStorage['last']);
      if (last.origin != null) {
        $('#origin').val(last.origin);
      }
      if (last.destination != null) {
        $('#destination').val(last.destination);
      }
    }
    $(document.body).css('padding-top', $('#header').outerHeight(true));
    $('#option-container').css('bottom', $('#footer').outerHeight(true));
    $map = $('#map');
    $map.height(innerHeight - $('#header').outerHeight(true) - $('#footer').outerHeight(true));
    $('#pin-list-frame').css('height', innerHeight - mapSum($('#window-bookmark .btn-toolbar').toArray(), function(e) {
      return $(e).outerHeight(true);
    }) + 'px');
    $gps = $('#gps');
    $gps.on('click', function() {
      return mapFSM.gpsClicked();
    });
    $('.search-query').parent().on('submit', function() {
      return false;
    });
    $('#address').on('change', geocodeHandler);
    $('.search-query').on('keyup', function() {
      var $this;
      $this = $(this);
      if ($this.val() === '') {
        return $this.siblings('.btn-bookmark').css('display', 'block');
      } else {
        return $this.siblings('.btn-bookmark').css('display', 'none');
      }
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
    backToMap = function() {
      $map.css('top', '');
      return $option.removeClass('btn-primary');
    };
    $option = $('#option');
    $option.on('click', function() {
      $('#option-container').css('display', 'block');
      if ($option.hasClass('btn-primary')) {
        return backToMap();
      } else {
        $map.css('top', -$('#option-container').outerHeight(true) + 'px');
        return $option.addClass('btn-primary');
      }
    });
    $mapType = $('#map-type');
    $mapType.children(':not(#panel)').on('click', function() {
      var $this;
      $this = $(this);
      if ($this.hasClass('btn-primary')) {
        return;
      }
      $mapType.children().removeClass('btn-primary');
      $this.addClass('btn-primary');
      map.setMapTypeId(getMapType());
      return backToMap();
    });
    $traffic = $('#traffic');
    trafficLayer = new google.maps.TrafficLayer();
    $traffic.on('click', function() {
      if ($traffic.text() === '渋滞状況を表示') {
        trafficLayer.setMap(map);
        $traffic.text('渋滞状況を隠す');
      } else {
        trafficLayer.setMap(null);
        $traffic.text('渋滞状況を表示');
      }
      return backToMap();
    });
    $('#replace-pin').on('click', function() {
      droppedMarker.setPosition(map.getCenter());
      droppedMarker.setVisible(true);
      return backToMap();
    });
    $('#print').on('click', function() {
      setTimeout(window.print, 0);
      return backToMap();
    });
    $(document).on('click', '#street-view', function(event) {
      return new google.maps.StreetViewService().getPanoramaByLocation(droppedMarker.getPosition(), 49, getLocationHandler);
    });
    $('.btn-bookmark').on('click', function() {
      bookmarkContext = $(this).siblings('input').attr('id');
      if (bookmarkContext === 'address') {
        mapFSM.bookmarkClicked();
      }
      return $('#window-bookmark').css('bottom', '0');
    });
    $('#bookmark-done').on('click', function() {
      return $('#window-bookmark').css('bottom', '-100%');
    });
    $('#pin-list td').on('click', function() {
      name = $(this).data('object-name');
      if (!((name != null) && name !== '')) {
        return;
      }
      switch (bookmarkContext) {
        case 'address':
          if (name === 'pulsatingMarker') {
            mapFSM.currentPositionClicked();
          }
      }
      return $('#window-bookmark').css('bottom', '-100%');
    });
    return window.onpagehide = function() {
      if (!traceHandler.id) {
        navigator.geolocation.clearWatch(traceHandler.id);
      }
      return saveStatus();
    };
  };

  initializeGoogleMaps();

  initializeDOM();

}).call(this);
