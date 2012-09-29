// Generated by CoffeeScript 1.3.3
(function() {
  var geocoder, initializeDOM, initializeGoogleMaps, map, traceHeadingEnable, watchId;

  watchId = null;

  traceHeadingEnable = false;

  geocoder = null;

  map = null;

  initializeGoogleMaps = function() {
    var destinationMarker, droppedMarker, getLocationHandler, myOptions, pulsatingMarker, startMarker, traceHandler;
    myOptions = (function() {
      var last, lat, lng, zoom;
      if (localStorage['last'] != null) {
        last = JSON.parse(localStorage['last']);
        lat = last.lat;
        lng = last.lng;
        zoom = last.zoom;
      } else {
        lat = 35.660389;
        lng = 139.729225;
        zoom = 14;
      }
      return {
        zoom: zoom,
        center: new google.maps.LatLng(lat, lng),
        mapTypeId: google.maps.MapTypeId.ROADMAP,
        disableDefaultUI: true
      };
    })();
    geocoder = new google.maps.Geocoder();
    map = new google.maps.Map(document.getElementById("map"), myOptions);
    window.map = map;
    droppedMarker = new google.maps.Marker({
      map: map,
      position: myOptions.center,
      title: 'ドロップされたピン',
      visible: false
    });
    pulsatingMarker = null;
    startMarker = null;
    destinationMarker = null;
    google.maps.event.addListener(map, 'click', function(event) {
      droppedMarker.setVisible(true);
      return droppedMarker.setPosition(event.latLng);
    });
    google.maps.event.addListener(map, 'center_changed', function() {
      var pos;
      pos = map.getCenter();
      return localStorage['last'] = JSON.stringify({
        lat: pos.lat(),
        lng: pos.lng(),
        zoom: map.getZoom()
      });
    });
    google.maps.event.addListener(map, 'zoom_changed', function() {
      var pos;
      pos = map.getCenter();
      return localStorage['last'] = JSON.stringify({
        lat: pos.lat(),
        lng: pos.lng(),
        zoom: map.getZoom()
      });
    });
    google.maps.event.addListener(droppedMarker, 'click', function(event) {
      return new google.maps.StreetViewService().getPanoramaByLocation(droppedMarker.getPosition(), 49, getLocationHandler);
    });
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
    return traceHandler = function(position) {
      var latLng, transform;
      latLng = new google.maps.LatLng(position.coords.latitude, position.coords.longitude);
      if (pulsatingMarker) {
        pulsatingMarker.setPosition(latLng);
      } else {
        pulsatingMarker = new google.maps.Marker({
          flat: true,
          icon: new google.maps.MarkerImage('img/bluedot.png')
        }, null, null, new google.maps.Point(8, 8), new google.maps.Size(17, 17), {
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
  };

  initializeDOM = function() {
    var $gps, $map, squareSize;
    squareSize = Math.floor(Math.sqrt(Math.pow(innerWidth, 2) + Math.pow(innerHeight, 2)));
    $map = $('#map');
    $map.width(squareSize).height(squareSize).css('margin', -squareSize / 2 + 'px');
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
          $gps.data('status', 'trace-heading');
          traceHeadingEnable = true;
          $gps.children('i').removeClass('icon-globe');
          return $gps.children('i').addClass('icon-hand-up');
        case 'trace-heading':
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
    return window.onpagehide = function() {
      var pos;
      if (!watchId) {
        navigator.geolocation.clearWatch(watchId);
      }
      pos = map.getCenter();
      return localStorage['last'] = JSON.stringify({
        lat: pos.lat(),
        lng: pos.lng(),
        zoom: map.getZoom()
      });
    };
  };

  initializeGoogleMaps();

  initializeDOM();

}).call(this);
