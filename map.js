// Generated by CoffeeScript 1.3.3
(function() {
  var $addressField, $destinationField, $gps, $map, $originField, $pinList, Bookmark, MSMARKER_SHADOW, MapFSM, MapState, PURPLE_DOT_IMAGE, RED_DOT_IMAGE, WatchPosition, bookmarkContext, bookmarks, currentBookmark, directionsRenderer, droppedBookmark, generateBookmarkList, generateHistoryList, geocoder, getMapType, getPanoramaHandler, getTravelMode, history, infoWindow, initializeDOM, initializeGoogleMaps, makeInfoMessage, map, mapFSM, mapSum, meterToString, method, name, naviMarker, navigate, pinRowHeight, pulsatingMarker, saveMapStatus, saveOtherStatus, searchAddress, searchBookmark, searchDirections, secondToString, setInfoPage, sum, traceHandler, updateField, _ref;

  PURPLE_DOT_IMAGE = 'http://maps.google.co.jp/mapfiles/ms/icons/purple-dot.png';

  RED_DOT_IMAGE = 'http://maps.google.co.jp/mapfiles/ms/icons/red-dot.png';

  MSMARKER_SHADOW = 'http://maps.google.co.jp/mapfiles/ms/icons/msmarker.shadow.png';

  map = null;

  geocoder = null;

  directionsRenderer = null;

  pulsatingMarker = null;

  naviMarker = null;

  infoWindow = null;

  droppedBookmark = null;

  searchBookmark = null;

  currentBookmark = null;

  $map = null;

  $gps = null;

  $addressField = null;

  $originField = null;

  $destinationField = null;

  $pinList = null;

  pinRowHeight = null;

  mapFSM = null;

  bookmarkContext = null;

  bookmarks = [];

  history = [];

  WatchPosition = (function() {

    function WatchPosition() {}

    WatchPosition.prototype.start = function(dummy) {
      this.id = navigator.geolocation.watchPosition.apply(navigator.geolocation, Array.prototype.slice.call(arguments));
      return this;
    };

    WatchPosition.prototype.stop = function() {
      if (!this.id) {
        navigator.geolocation.clearWatch(this.id);
      }
      this.id = null;
      return this;
    };

    return WatchPosition;

  })();

  MapState = (function() {

    function MapState(name) {
      this.name = name;
    }

    MapState.NORMAL = new MapState('normal');

    MapState.TRACE_POSITION = new MapState('trace_position');

    MapState.TRACE_HEADING = new MapState('trace_heading');

    MapState.prototype.update = function() {
      return this;
    };

    MapState.prototype.gpsClicked = function() {
      return this;
    };

    MapState.prototype.bookmarkClicked = function() {
      return this;
    };

    return MapState;

  })();

  MapState.NORMAL.update = function() {
    $gps.removeClass('btn-primary');
    return this;
  };

  MapState.NORMAL.gpsClicked = function() {
    return MapState.TRACE_POSITION;
  };

  MapState.TRACE_POSITION.update = function() {
    map.setCenter(pulsatingMarker.getPosition());
    $gps.addClass('btn-primary');
    return this;
  };

  MapState.TRACE_POSITION.gpsClicked = function() {
    return MapState.NORMAL;
  };

  MapState.TRACE_HEADING.update = function() {
    return this;
  };

  MapState.TRACE_HEADING.gpsClicked = function() {
    return MapState.NORMAL;
  };

  MapState.TRACE_HEADING.bookmarkClicked = function() {
    return MapState.TRACE_POSITION;
  };

  MapFSM = (function() {

    function MapFSM(state) {
      this.state = state;
    }

    MapFSM.prototype.is = function(state) {
      return this.state === state;
    };

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

  Bookmark = (function() {

    function Bookmark(marker, address) {
      var _this = this;
      this.marker = marker;
      this.address = address;
      google.maps.event.addListener(this.marker, 'click', function(event) {
        currentBookmark = _this;
        return _this.showInfoWindow();
      });
    }

    Bookmark.prototype.showInfoWindow = function() {
      infoWindow.setContent(makeInfoMessage(this.marker.getTitle(), this.address));
      return infoWindow.open(map, this.marker);
    };

    Bookmark.prototype.toObject = function() {
      var pos;
      pos = this.marker.getPosition();
      return {
        lat: pos.lat(),
        lng: pos.lng(),
        title: this.marker.getTitle(),
        address: this.address
      };
    };

    return Bookmark;

  })();

  saveMapStatus = function() {
    var pos;
    pos = map.getCenter();
    return localStorage['maps-map-status'] = JSON.stringify({
      lat: pos.lat(),
      lng: pos.lng(),
      zoom: map.getZoom()
    });
  };

  saveOtherStatus = function() {
    return localStorage['maps-other-status'] = JSON.stringify({
      origin: $originField.val(),
      destination: $destinationField.val(),
      bookmarks: bookmarks.map(function(e) {
        return e.toObject();
      }),
      history: history
    });
  };

  sum = function(array) {
    return array.reduce(function(a, b) {
      return a + b;
    });
  };

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

  makeInfoMessage = function(title, message) {
    return "<table id=\"info-window\"><tr>\n    <td><button id=\"street-view\" class=\"btn\"><i class=\"icon-user\"></i></button></td>\n    <td style=\"white-space: nowrap;\"><div style=\"max-width:160px;overflow:hidden;\">" + title + "<br><span id=\"dropped-message\" style=\"font-size:10px\">" + message + "</span></div></td>\n    <td><button id=\"button-info\" class\"btn\"><i class=\"icon-chevron-right\"></i></button></td>\n</tr></table>";
  };

  updateField = function($field, str) {
    return $field.val(str).siblings('.btn-bookmark').css('display', str === '' ? 'block' : 'none');
  };

  searchDirections = function(fromHistory) {
    var destination, origin;
    if (fromHistory == null) {
      fromHistory = false;
    }
    origin = $originField.val();
    destination = $destinationField.val();
    if (!(((origin != null) && origin !== '') && ((destination != null) && destination !== ''))) {
      return;
    }
    if (fromHistory) {
      history.unshift({
        type: 'route',
        origin: origin,
        destination: destination
      });
    }
    return searchDirections.service.route({
      destination: destination,
      origin: origin,
      provideRouteAlternatives: getTravelMode() !== google.maps.TravelMode.WALKING,
      travelMode: getTravelMode()
    }, function(result, status) {
      var $message, distance, duration, index, message, summary;
      $message = $('#message');
      message = '';
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
        $('#navi-header2').css('display', 'block');
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
    steps = navigate.step + (navigate.leg === 0 ? 0 : sum(lengths.slice(0, navigate.leg)));
    $('#numbering').text((steps + 1) + '/' + mapSum(route.legs, function(e) {
      return e.steps.length;
    }));
    return $('#message').html(step.instructions);
  };

  navigate.leg = null;

  navigate.step = null;

  setInfoPage = function(bookmark, dropped) {
    var position, title, _ref1, _ref2;
    console.log(bookmark.marker.getIcon());
    $('#info-marker img:first-child').attr('src', (_ref1 = (_ref2 = bookmark.marker.getIcon()) != null ? _ref2.url : void 0) != null ? _ref1 : 'http://maps.google.co.jp/mapfiles/ms/icons/red-dot.png');
    title = bookmark.marker.getTitle();
    position = bookmark.marker.getPosition();
    $('#info-name').text(title);
    $('#bookmark-name input[name="bookmark-name"]').val(dropped ? bookmark.address : title);
    $('#info-address').text(bookmark.address);
    return $('#send-place').attr('href', "mailto:?subject=" + title + "&body=<a href=\"https://maps.google.co.jp/maps?q=" + (position.lat()) + "," + (position.lng()) + "\">" + title + "</a>");
  };

  generateBookmarkList = function() {
    var e, i, list, _i, _len;
    list = '<tr><td data-object-name="pulsatingMarker">現在地</td></tr>';
    if (droppedBookmark.marker.getVisible()) {
      list += '<tr><td data-object-name="droppedBookmark">ドロップされたピン</td></tr>';
    }
    for (i = _i = 0, _len = bookmarks.length; _i < _len; i = ++_i) {
      e = bookmarks[i];
      list += "<tr><td data-object-name=\"bookmarks[" + i + "]\">" + (e.marker.getTitle()) + "</td></tr>";
    }
    list += Array(Math.max(1, Math.floor(innerHeight / pinRowHeight) - bookmarks.length)).join('<tr><td></td></tr>');
    return $pinList.html(list);
  };

  generateHistoryList = function() {
    var e, i, list, print, _i, _len;
    print = function(e) {
      switch (e.type) {
        case 'search':
          return "検索: " + e.address;
        case 'route':
          return "出発: " + e.origin + "<br>到着: " + e.destination;
      }
    };
    list = '';
    for (i = _i = 0, _len = history.length; _i < _len; i = ++_i) {
      e = history[i];
      list += "<tr><td data-object-name=\"history[" + i + "]\">" + (print(e)) + "</td></tr>";
    }
    list += Array(Math.max(1, Math.floor(innerHeight / pinRowHeight) - history.length)).join('<tr><td></td></tr>');
    return $pinList.html(list);
  };

  searchAddress = function(fromHistory) {
    var address;
    address = $addressField.val();
    if (!((address != null) && address !== '')) {
      return;
    }
    infoWindow.close();
    searchBookmark.marker.setVisible(false);
    if (!fromHistory) {
      history.unshift({
        type: 'search',
        address: address
      });
    }
    return geocoder.geocode({
      address: address
    }, function(result, status) {
      if (status === google.maps.GeocoderStatus.OK) {
        mapFSM.setState(MapState.NORMAL);
        map.setCenter(result[0].geometry.location);
        searchBookmark.address = result[0].formatted_address;
        searchBookmark.marker.setPosition(result[0].geometry.location);
        searchBookmark.marker.setTitle(address);
        searchBookmark.marker.setVisible(true);
        searchBookmark.marker.setAnimation(google.maps.Animation.DROP);
        return currentBookmark = searchBookmark;
      } else {
        return alert(status);
      }
    });
  };

  getPanoramaHandler = function(data, status) {
    var sv, _ref1;
    switch (status) {
      case google.maps.StreetViewStatus.OK:
        sv = map.getStreetView();
        sv.setPosition(data.location.latLng);
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
    if (!mapFSM.is(MapState.NORMAL)) {
      map.setCenter(latLng);
    }
    if (mapFSM.is(MapState.TRACE_HEADING && (position.coords.heading != null))) {
      transform = $map.css('-webkit-transform');
      if (/rotate(-?[\d.]+deg)/.test(transform)) {
        transform = transform.replace(/rotate(-?[\d.]+deg)/, "rotate(" + (-position.coords.heading) + "deg)");
      } else {
        transform = transform + (" rotate(" + (-position.coords.heading) + "deg)");
      }
      return $map.css('-webkit-transform', transform);
    }
  };

  initializeGoogleMaps = function() {
    var mapOptions, mapStatus;
    mapOptions = {
      mapTypeId: getMapType(),
      disableDefaultUI: true
    };
    if (localStorage['maps-map-status'] != null) {
      mapStatus = JSON.parse(localStorage['maps-map-status']);
      mapOptions.center = new google.maps.LatLng(mapStatus.lat, mapStatus.lng);
      mapOptions.zoom = mapStatus.zoom;
    } else {
      mapOptions.center = new google.maps.LatLng(35.660389, 139.729225);
      mapOptions.zoom = 14;
    }
    map = new google.maps.Map(document.getElementById("map"), mapOptions);
    mapFSM = new MapFSM(MapState.NORMAL);
    geocoder = new google.maps.Geocoder();
    directionsRenderer = new google.maps.DirectionsRenderer();
    directionsRenderer.setMap(map);
    google.maps.event.addListener(directionsRenderer, 'directions_changed', function() {
      navigate.leg = null;
      navigate.step = null;
      $('#navi-header2').css('display', 'none');
      return naviMarker.setVisible(false);
    });
    droppedBookmark = new Bookmark(new google.maps.Marker({
      animation: google.maps.Animation.DROP,
      map: map,
      icon: new google.maps.MarkerImage(PURPLE_DOT_IMAGE),
      shadow: new google.maps.MarkerImage(MSMARKER_SHADOW, null, null, new google.maps.Point(16, 32)),
      position: mapOptions.center,
      title: 'ドロップされたピン',
      visible: false
    }), '');
    searchBookmark = new Bookmark(new google.maps.Marker({
      animation: google.maps.Animation.DROP,
      map: map,
      position: mapOptions.center,
      visible: false
    }), '');
    infoWindow = new google.maps.InfoWindow({
      maxWidth: Math.floor(innerWidth * 0.9)
    });
    naviMarker = new google.maps.Marker({
      flat: true,
      icon: new google.maps.MarkerImage('img/bluedot.png', null, null, new google.maps.Point(8, 8), new google.maps.Size(17, 17)),
      map: map,
      optimized: false,
      visible: false
    });
    google.maps.event.addListener(map, 'click', function(event) {
      infoWindow.close();
      droppedBookmark.address = '';
      droppedBookmark.marker.setVisible(true);
      droppedBookmark.marker.setPosition(event.latLng);
      droppedBookmark.marker.setAnimation(google.maps.Animation.DROP);
      currentBookmark = droppedBookmark;
      return geocoder.geocode({
        latLng: event.latLng
      }, function(result, status) {
        droppedBookmark.address = status === google.maps.GeocoderStatus.OK ? result[0].formatted_address.replace(/日本, /, '') : '情報がみつかりませんでした。';
        return infoWindow.setContent(makeInfoMessage(droppedBookmark.marker.getTitle(), droppedBookmark.address));
      });
    });
    google.maps.event.addListener(droppedBookmark.marker, 'animation_changed', function() {
      if (!(this.getAnimation() != null)) {
        return droppedBookmark.showInfoWindow();
      }
    });
    google.maps.event.addListener(searchBookmark.marker, 'animation_changed', function() {
      if (!(this.getAnimation() != null)) {
        return searchBookmark.showInfoWindow();
      }
    });
    google.maps.event.addListener(map, 'dragstart', function() {
      return mapFSM.setState(MapState.NORMAL);
    });
    google.maps.event.addListener(map, 'center_changed', saveMapStatus);
    return google.maps.event.addListener(map, 'zoom_changed', saveMapStatus);
  };

  initializeDOM = function() {
    var $edit, $mapType, $naviHeader, $option, $route, $routeSearchFrame, $search, $traffic, $travelMode, $versatile, backToMap, e, openRouteForm, otherStatus, trafficLayer, visibleSearchHeaderHeight, watchPosition, _i, _len, _ref1, _ref2, _ref3;
    $map = $('#map');
    $gps = $('#gps');
    $addressField = $('#address input[name="address"]');
    $originField = $('#origin input[name="origin"]');
    $destinationField = $('#destination input[name="destination"]');
    $pinList = $('#pin-list');
    pinRowHeight = $('#pin-list tr').height();
    document.addEventListener('touchmove', function(event) {
      return event.preventDefault();
    });
    $('#pin-list-frame, #info').on('touchmove', function(event) {
      return event.stopPropagation();
    });
    if (localStorage['maps-other-status'] != null) {
      otherStatus = JSON.parse(localStorage['maps-other-status']);
      if ((otherStatus.origin != null) && otherStatus.origin !== '') {
        updateField($originField, otherStatus.origin);
      }
      if ((otherStatus.destination != null) && otherStatus.destination !== '') {
        updateField($destinationField, otherStatus.destination);
      }
      _ref2 = (_ref1 = otherStatus.bookmarks) != null ? _ref1 : [];
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        e = _ref2[_i];
        bookmarks.push(new Bookmark(new google.maps.Marker({
          map: map,
          position: new google.maps.LatLng(e.lat, e.lng),
          title: e.title
        }), e.address));
      }
      history = (_ref3 = otherStatus.history) != null ? _ref3 : [];
    }
    $('#option-page').css('bottom', $('#footer').outerHeight(true));
    visibleSearchHeaderHeight = $('#search-header').outerHeight(true) + parseInt($('#search-header').css('top'));
    $map.css('top', visibleSearchHeaderHeight + 'px');
    $map.height(innerHeight - visibleSearchHeaderHeight - $('#footer').outerHeight(true));
    $('#pin-list-frame').css('height', innerHeight - mapSum($('#bookmark-page .btn-toolbar').toArray(), function(e) {
      return $(e).outerHeight(true);
    }) + 'px');
    $('.search-query').on('keyup', function() {
      var $this;
      $this = $(this);
      if ($this.val() === '') {
        return $this.siblings('.btn-bookmark').css('display', 'block');
      } else {
        return $this.siblings('.btn-bookmark').css('display', 'none');
      }
    });
    $('#clear, .btn-reset').on('mousedown', function(event) {
      return event.preventDefault();
    });
    $('.btn-reset').on('click', function() {
      return $(this).siblings('.btn-bookmark').css('display', 'block');
    });
    $('#clear').on('click', function() {
      return $('#address .btn-bookmark').css('display', 'block');
    });
    $gps.on('click', function() {
      return mapFSM.gpsClicked();
    });
    $addressField.on('focus', function() {
      return $('#search-header').css('top', '0');
    });
    $addressField.on('blur', function() {
      return $('#search-header').css('top', '');
    });
    $('#address').on('submit', function() {
      searchAddress(false);
      $addressField.blur();
      return false;
    });
    $addressField.on('keyup', function() {
      return $('#done').text($(this).val() === '' ? '完了' : 'キャンセル');
    });
    $('#clear, #address .btn-reset').on('click', function() {
      $('#done').text($(this).val() === '' ? '完了' : 'キャンセル');
      searchBookmark.marker.setVisible(false);
      if (currentBookmark === searchBookmark) {
        return infoWindow.setVisible(false);
      }
    });
    $naviHeader = $('#navi-header1');
    $search = $('#search');
    $search.on('click', function() {
      directionsRenderer.setMap(null);
      naviMarker.setVisible(false);
      $route.removeClass('btn-primary');
      $search.addClass('btn-primary');
      return $naviHeader.css('display', 'none');
    });
    $route = $('#route');
    $route.on('click', function() {
      $search.removeClass('btn-primary');
      $route.addClass('btn-primary');
      $naviHeader.css('display', 'block');
      return directionsRenderer.setMap(map);
    });
    $edit = $('#edit');
    $versatile = $('#versatile');
    $routeSearchFrame = $('#route-search-frame');
    openRouteForm = function() {
      $edit.text('キャンセル');
      $versatile.text('経路');
      $('#navi-header2').css('display', 'none');
      return $routeSearchFrame.css('top', '0px');
    };
    $edit.on('click', function() {
      if ($edit.text() === '編集') {
        return openRouteForm();
      } else {
        $edit.text('編集');
        $versatile.text('出発');
        if ((navigate.leg != null) && (navigate.step != null)) {
          $('#navi-header2').css('display', 'block');
        }
        return $routeSearchFrame.css('top', '');
      }
    });
    $('#edit2').on('click', function() {
      return $edit.trigger('click');
    });
    $('#switch').on('click', function() {
      var tmp;
      tmp = $destinationField.val();
      updateField($destinationField, $originField.val());
      updateField($originField, tmp);
      return saveOtherStatus();
    });
    $originField.on('change', saveOtherStatus);
    $destinationField.on('change', saveOtherStatus);
    $travelMode = $('#travel-mode');
    $travelMode.children(':not(#transit)').on('click', function() {
      var $this;
      $this = $(this);
      if ($this.hasClass('btn-primary')) {
        return;
      }
      $travelMode.children().removeClass('btn-primary');
      $this.addClass('btn-primary');
      return searchDirections(false);
    });
    $versatile.on('click', function() {
      switch ($versatile.text()) {
        case '経路':
          $edit.text('編集');
          $versatile.text('出発');
          $routeSearchFrame.css('top', '');
          return searchDirections(false);
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
      $('#option-page').css('display', 'block');
      if ($option.hasClass('btn-primary')) {
        return backToMap();
      } else {
        $map.css('top', -$('#option-page').outerHeight(true) + 'px');
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
      droppedBookmark.marker.setPosition(map.getCenter());
      droppedBookmark.marker.setVisible(true);
      return backToMap();
    });
    $('#print').on('click', function() {
      setTimeout(window.print, 0);
      return backToMap();
    });
    $(document).on('click', '#street-view', function(event) {
      return new google.maps.StreetViewService().getPanoramaByLocation(currentBookmark.marker.getPosition(), 49, getPanoramaHandler);
    });
    $(document).on('click', '#button-info', function(event) {
      setInfoPage(currentBookmark, currentBookmark === droppedBookmark);
      return $('#container').css('right', '100%');
    });
    $('#button-map').on('click', function() {
      return $('#container').css('right', '');
    });
    $('.btn-bookmark').on('click', function() {
      mapFSM.bookmarkClicked();
      bookmarkContext = $(this).parent().attr('id');
      generateBookmarkList();
      return $('#bookmark-page').css('bottom', '0');
    });
    $('#bookmark-done').on('click', function() {
      return $('#bookmark-page').css('bottom', '-100%');
    });
    $(document).on('click', '#pin-list td', function() {
      var bookmarkOrMarker, item, latLng;
      name = $(this).data('object-name');
      if (!((name != null) && name !== '')) {
        return;
      }
      if (/history/.test(name)) {
        item = eval(name);
        switch (item.type) {
          case 'search':
            updateField($addressField, item.address);
            $search.trigger('click');
            searchAddress(true);
            break;
          case 'route':
            updateField($originField, item.origin);
            updateField($destinationField, item.destination);
            $route.trigger('click');
            searchDirections(true);
        }
      } else {
        bookmarkOrMarker = eval(name);
        switch (bookmarkContext) {
          case 'address':
            map.getStreetView().setVisible(false);
            if (name === 'pulsatingMarker') {
              mapFSM.setState(MapState.TRACE_POSITION);
            } else {
              mapFSM.setState(MapState.NORMAL);
              console.log(bookmarkOrMarker.address);
              console.log(bookmarkOrMarker !== droppedBookmark);
              if (bookmarkOrMarker !== droppedBookmark) {
                updateField($addressField, bookmarkOrMarker.address);
              }
              map.setCenter(bookmarkOrMarker.marker.getPosition());
              currentBookmark = bookmarkOrMarker;
              bookmarkOrMarker.showInfoWindow();
            }
            break;
          case 'origin':
            updateField($originField, name === 'pulsatingMarker' ? (latLng = bookmarkOrMarker.getPosition(), "" + (latLng.lat()) + ", " + (latLng.lng())) : bookmarkOrMarker.address);
            break;
          case 'destination':
            updateField($destinationField, name === 'pulsatingMarker' ? (latLng = bookmarkOrMarker.getPosition(), "" + (latLng.lat()) + ", " + (latLng.lng())) : bookmarkOrMarker.address);
        }
      }
      return $('#bookmark-page').css('bottom', '-100%');
    });
    $('#add-bookmark').on('click', function() {
      return $('#add-bookmark-page').css('top', '0');
    });
    $('#cancel-add-bookmark').on('click', function() {
      return $('#add-bookmark-page').css('top', '');
    });
    $('#delete-pin').on('click', function() {
      var index;
      if (currentBookmark === droppedBookmark) {
        droppedBookmark.marker.setVisible(false);
      } else {
        index = bookmarks.indexOf(currentBookmark);
        bookmarks.splice(index, 1);
        currentBookmark.marker.setMap(null);
      }
      infoWindow.close();
      return $('#container').css('right', '');
    });
    $('#save-bookmark').on('click', function() {
      var bookmark;
      bookmark = new Bookmark(new google.maps.Marker({
        map: map,
        position: currentBookmark.marker.getPosition(),
        title: $('#bookmark-name input[name="bookmark-name"]').val()
      }), $('#info-address').text());
      bookmarks.push(bookmark);
      bookmark.showInfoWindow();
      saveOtherStatus();
      $('#add-bookmark-page').css('top', '');
      return $('#container').css('right', '');
    });
    $('#nav-bookmark button').on('click', function() {
      var $this;
      $this = $(this);
      $('#nav-bookmark button').removeClass('btn-primary');
      $this.addClass('btn-primary');
      switch ($this.attr('id')) {
        case 'bookmark':
          $('#bookmark-message').text('マップ上に表示するブックマークを選択');
          $('#bookmark-edit').text('編集').addClass('disabled');
          return generateBookmarkList();
        case 'history':
          $('#bookmark-message').text('検索履歴を選択');
          $('#bookmark-edit').text('消去').removeClass('disabled');
          return generateHistoryList();
      }
    });
    $('#to-here').on('click', function() {
      updateField($destinationField, currentBookmark.address);
      $route.trigger('click');
      $('#container').css('right', '');
      return openRouteForm();
    });
    $('#from-here').on('click', function() {
      updateField($originField, currentBookmark.address);
      $route.trigger('click');
      $('#container').css('right', '');
      return openRouteForm();
    });
    watchPosition = new WatchPosition().start(traceHandler, function(error) {
      return console.log(error.message, {
        enableHighAccuracy: true,
        timeout: 30000
      });
    });
    return window.onpagehide = function() {
      watchPosition.stop();
      saveMapStatus();
      return saveOtherStatus();
    };
  };

  initializeGoogleMaps();

  initializeDOM();

}).call(this);
