// Generated by CoffeeScript 1.3.3
(function() {
  var $gps, geocoder, getLocationHandler, image, latlng, map, marker, myMarker, myOptions, traceHandler, traceHeadingEnable, watchId;

  watchId = null;

  traceHeadingEnable = false;

  latlng = new google.maps.LatLng(35.757794, 139.876819);

  myOptions = {
    zoom: 16,
    center: latlng,
    mapTypeId: google.maps.MapTypeId.ROADMAP,
    disableDefaultUI: true
  };

  geocoder = new google.maps.Geocoder();

  map = new google.maps.Map(document.getElementById("map"), myOptions);

  image = new google.maps.MarkerImage('img/bluedot.png', null, null, new google.maps.Point(8, 8), new google.maps.Size(17, 17));

  myMarker = null;

  marker = new google.maps.Marker({
    map: map,
    position: latlng,
    title: 'ドロップされたピン',
    visible: false
  });

  google.maps.event.addListener(map, 'click', function(event) {
    marker.setVisible(true);
    return marker.setPosition(event.latLng);
  });

  google.maps.event.addListener(marker, 'click', function(event) {
    return new google.maps.StreetViewService().getPanoramaByLocation(marker.getPosition(), 49, getLocationHandler);
  });

  getLocationHandler = function(data, status) {
    var sv, _ref;
    switch (status) {
      case google.maps.StreetViewStatus.OK:
        sv = map.getStreetView();
        sv.setPosition(data.location.latLng);
        marker.setPosition(data.location.latLng);
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

  traceHandler = function(position) {
    var latLng;
    latLng = new google.maps.LatLng(position.coords.latitude, position.coords.longitude);
    if (myMarker) {
      myMarker.setPosition(latLng);
    } else {
      myMarker = new google.maps.Marker({
        flat: true,
        icon: image,
        map: map,
        optimized: false,
        position: latLng,
        title: 'I might be here',
        visible: true
      });
    }
    map.setCenter(latLng);
    if (traceHeadingEnable) {
      return map.setHeading(position.coords.heading);
    }
  };

  $('#map').height(window.innerHeight - $('#header').outerHeight(true) - $('#footer').outerHeight(true));

  $gps = $('#gps');

  $gps.data('status', 'normal');

  $gps.on('click', function() {
    switch ($gps.data('status')) {
      case 'normal':
        $gps.addClass('btn-primary');
        traceHeadingEnable = false;
        map.setHeading(0);
        watchId = navigator.geolocation.watchPosition(traceHandler, function(error) {
          return console.log(error.message);
        }, {
          enableHighAccuracy: true,
          timeout: 30000
        });
        return $gps.data('status', 'trace-position');
      case 'trace-position':
        traceHeadingEnable = true;
        $gps.addClass('btn-primary');
        $gps.children('i').removeClass('icon-globe');
        $gps.children('i').addClass('icon-hand-up');
        return $gps.data('status', 'trace-heading');
      case 'trace-heading':
        navigator.geolocation.clearWatch(watchId);
        watchId = null;
        map.setHeading(0);
        $gps.removeClass('btn-primary');
        $gps.children('i').removeClass('icon-hand-up');
        $gps.children('i').addClass('icon-globe');
        return $gps.data('status', 'normal');
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

  window.onpagehide = function() {
    console.log('hide');
    if (!watchId) {
      return navigator.geolocation.clearWatch(watchId);
    }
  };

}).call(this);
