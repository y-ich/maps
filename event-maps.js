// Generated by CoffeeScript 1.6.1
(function() {
  var CLIENT_ID, Event, MAP_STATUS, Place, SCOPES, TIME_ZONE_HOST, calendars, compareEventResources, currentCalendar, currentPlace, directions, directionsRenderer, geocoder, getLocalizedString, getTimeZone, handleAuthResult, initializeDOM, initializeGoogleMaps, localTime, localize, map, mapSum, modalPlace, originPlace, saveMapStatus, searchDirections, setLocalExpressionInto, spinner, sum, timeDifference,
    _this = this,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  CLIENT_ID = '369757625302.apps.googleusercontent.com';

  SCOPES = ['https://www.googleapis.com/auth/calendar'];

  MAP_STATUS = 'spacetime-map-status';

  TIME_ZONE_HOST = 'http://safari-park.herokuapp.com';

  map = null;

  directionsRenderer = null;

  calendars = null;

  currentCalendar = null;

  currentPlace = null;

  modalPlace = null;

  originPlace = null;

  directions = null;

  geocoder = null;

  spinner = new Spinner({
    color: '#000'
  });

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

  handleAuthResult = function(result) {
    if ((result != null) && (result.error == null)) {
      return gapi.client.load('calendar', 'v3', function() {
        $('#button-authorize').css('display', 'none');
        return $('#button-calendar').css('display', '');
      });
    } else {
      return $('#button-authorize').text('このアプリ"EventMaps"にGoogleカレンダーへのアクセスを許可する').attr('disabled', null).addClass('primary');
    }
  };

  getLocalizedString = function(key) {
    var _ref;
    if (typeof localizedStrings !== "undefined" && localizedStrings !== null) {
      return (_ref = localizedStrings[key]) != null ? _ref : key;
    } else {
      return key;
    }
  };

  setLocalExpressionInto = function(id, english) {
    var el;
    el = document.getElementById(id);
    if (el != null) {
      return el.lastChild.data = getLocalizedString(english);
    }
  };

  localize = function() {
    var idWordPairs, key, value, _results;
    idWordPairs = [];
    document.title = getLocalizedString('EventMaps');
    _results = [];
    for (key in idWordPairs) {
      value = idWordPairs[key];
      _results.push(setLocalExpressionInto(key, value));
    }
    return _results;
  };

  saveMapStatus = function() {
    var pos;
    pos = map.getCenter();
    return localStorage[MAP_STATUS] = JSON.stringify({
      lat: pos.lat(),
      lng: pos.lng(),
      zoom: map.getZoom()
    });
  };

  timeDifference = function(offset) {
    var offsetHours, offsetMinutes, twoDigitsFormat;
    twoDigitsFormat = function(n) {
      if (n < 10) {
        return '0' + n;
      } else {
        return n.toString();
      }
    };
    offsetHours = Math.floor(offset / (60 * 60));
    offsetMinutes = Math.floor(offset / 60 - offsetHours * 60);
    return (offset >= 0 ? '+' : '-') + twoDigitsFormat(offsetHours) + twoDigitsFormat(offsetMinutes);
  };

  localTime = function(date, offset) {
    return new Date(date.getTime() + offset * 1000).toISOString().replace(/\..*Z/, timeDifference(offset));
  };

  getTimeZone = function(date, position, callback) {
    var location, timestamp;
    if (getTimeZone.overQueryLimit) {
      return false;
    }
    location = "" + (position.lat()) + "," + (position.lng());
    timestamp = Math.floor(date.getTime() / 1000);
    return $.getJSON("" + TIME_ZONE_HOST + "/timezone/json?location=" + location + "&timestamp=" + timestamp + "&sensor=false&callback=?", function(obj) {
      switch (obj.status) {
        case 'OK':
          return callback(obj);
        case 'OVER_QUERY_LIMIT':
          timeZone.overQueryLimit = true;
          setTimeout((function() {
            return timeZone.overQueryLimit = false;
          }), 10000);
          return alert(obj.status);
        default:
          return console.error(obj);
      }
    });
  };

  getTimeZone.overQueryLimit = false;

  compareEventResources = function(x, y) {
    var _ref, _ref1;
    return new Date((_ref = x.start.dateTime) != null ? _ref : x.start.date + 'T00:00:00Z').getTime() - new Date((_ref1 = y.start.dateTime) != null ? _ref1 : y.start.date + 'T00:00:00Z').getTime();
  };

  searchDirections = function(origin, destination, departureTime, callback) {
    var deferred, deferreds, e, options, results, travelModes, _i, _len;
    if (departureTime == null) {
      departureTime = null;
    }
    travelModes = [google.maps.TravelMode.BICYCLING, google.maps.TravelMode.DRIVING, google.maps.TravelMode.TRANSIT, google.maps.TravelMode.WALKING];
    deferreds = [];
    results = [];
    for (_i = 0, _len = travelModes.length; _i < _len; _i++) {
      e = travelModes[_i];
      deferred = $.Deferred();
      deferreds.push(deferred);
      options = {
        destination: destination,
        origin: origin,
        travelMode: e
      };
      if (departureTime != null) {
        options.transitOptions = {
          departureTime: departureTime
        };
      }
      searchDirections.service.route(options, (function(travelMode, deferred) {
        return function(result, status) {
          switch (status) {
            case google.maps.DirectionsStatus.OK:
              results.push(result);
          }
          return deferred.resolve();
        };
      })(e, deferred));
    }
    return $.when.apply(window, deferreds).then(function() {
      return callback(results);
    });
  };

  searchDirections.service = new google.maps.DirectionsService();

  Place = (function(_super) {

    __extends(Place, _super);

    function Place(options, event, address) {
      var _this = this;
      this.event = event;
      this.address = address != null ? address : null;
      this.showInfo = function() {
        return Place.prototype.showInfo.apply(_this, arguments);
      };
      Place.__super__.constructor.call(this, options);
      google.maps.event.addListener(this, 'click', function() {
        if (originPlace != null) {
          return searchDirections(originPlace.getPosition(), _this.getPosition(), originPlace.event.getDate('end'), function(results) {
            var i, result, route, _i, _j, _len, _len1, _ref;
            for (i = _i = 0, _len = results.length; _i < _len; i = ++_i) {
              result = results[i];
              _ref = result.routes;
              for (_j = 0, _len1 = _ref.length; _j < _len1; _j++) {
                route = _ref[_j];
                route.distance = mapSum(result.routes[0].legs, function(e) {
                  return e.distance.value;
                });
                route.duration = mapSum(result.routes[0].legs, function(e) {
                  return e.duration.value;
                });
              }
            }
            results.sort(function(x, y) {
              return x.routes[0].duration - y.routes[0].duration;
            });
            directionsRenderer.setDirections(results[0]);
            directionsRenderer.setMap(map);
            $('#directions-panel').removeClass('hide');
            return directions = {
              results: results,
              index: 0,
              routeIndex: 0
            };
          });
        } else {
          return _this.showInfo();
        }
      });
    }

    Place.prototype.getDateTime = function(startOrEnd) {
      var dateTime, time, _ref;
      dateTime = (_ref = this.event.resource[startOrEnd].dateTime) != null ? _ref : this.event.resource[startOrEnd].date + 'T00:00:00Z';
      if (this["" + startOrEnd + "TimeZone"] != null) {
        time = localTime(new Date(dateTime), this["" + startOrEnd + "TimeZone"].dstOffset + this["" + startOrEnd + "TimeZone"].rawOffset);
        return {
          date: time.replace(/T.*/, ''),
          time: time.replace(/.*T|[Z+-].*/g, '')
        };
      } else {
        return {
          date: dateTime.replace(/T.*/, ''),
          time: dateTime.replace(/.*T|[Z+-].*/g, '')
        };
      }
    };

    Place.prototype.showInfo = function() {
      this.event.setModal(this);
      Event.$modalInfo.modal('show');
      directions = null;
      directionsRenderer.setMap(null);
      return $('#directions-panel').addClass('hide');
    };

    return Place;

  })(google.maps.Marker);

  Event = (function() {

    Event.$modalInfo = $('#modal-info');

    Event.events = [];

    Event.mark = 'A';

    Event.geocodeCount = 0;

    Event.shadow = {
      url: 'http://www.google.com/mapfiles/shadow50.png',
      anchor: new google.maps.Point(10, 34)
    };

    Event.clearAll = function() {
      var e, _i, _len, _ref;
      _ref = Event.events;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        e = _ref[_i];
        e.clearMarkers();
      }
      Event.events = [];
      return Event.mark = 'A';
    };

    function Event(calendarId, resource, centering, byClick) {
      var _base, _base1, _base2, _base3, _base4, _ref, _ref1, _ref2, _ref3, _ref4;
      this.calendarId = calendarId;
      this.resource = resource;
      if (centering == null) {
        centering = false;
      }
      if (byClick == null) {
        byClick = false;
      }
      if ((_ref = (_base = this.resource).summary) == null) {
        _base.summary = '新しい予定';
      }
      if ((_ref1 = (_base1 = this.resource).location) == null) {
        _base1.location = '';
      }
      if ((_ref2 = (_base2 = this.resource).description) == null) {
        _base2.description = '';
      }
      if ((_ref3 = (_base3 = this.resource).start) == null) {
        _base3.start = {
          dateTime: new Date().toISOString()
        };
      }
      if ((_ref4 = (_base4 = this.resource).end) == null) {
        _base4.end = {
          dateTime: new Date().toISOString()
        };
      }
      this.candidates = null;
      if ((this.latLng() != null) || ((this.resource.location != null) && this.resource.location !== '')) {
        this.icon = {
          url: "http://www.google.com/mapfiles/marker" + Event.mark + ".png"
        };
        if (Event.mark !== 'Z') {
          Event.mark = String.fromCharCode(Event.mark.charCodeAt(0) + 1);
        }
        this.tryToSetPlace(centering, byClick);
      }
      Event.events.push(this);
    }

    Event.prototype.clearMarkers = function() {
      var e, _i, _len, _ref;
      if (this.place != null) {
        this.place.setMap(null);
      }
      this.place = null;
      if (this.candicates != null) {
        _ref = this.candidates;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          e = _ref[_i];
          e.setMap(null);
        }
      }
      return this.candidates = null;
    };

    Event.prototype.getDate = function(startOrEnd) {
      var _ref;
      return new Date((_ref = this.resource[startOrEnd].dateTime) != null ? _ref : this.resource[startOrEnd].date + (startOrEnd === 'start' ? 'T00:00:00Z' : 'T23:59:59Z'));
    };

    Event.prototype.latLng = function() {
      var geolocation, _ref, _ref1;
      if (((_ref = this.resource.extendedProperties) != null ? (_ref1 = _ref["private"]) != null ? _ref1.geolocation : void 0 : void 0) != null) {
        geolocation = JSON.parse(this.resource.extendedProperties["private"].geolocation);
        return new google.maps.LatLng(geolocation.lat, geolocation.lng);
      } else {
        return null;
      }
    };

    Event.prototype.address = function() {
      var geolocation, _ref, _ref1;
      if (((_ref = this.resource.extendedProperties) != null ? (_ref1 = _ref["private"]) != null ? _ref1.geolocation : void 0 : void 0) != null) {
        geolocation = JSON.parse(this.resource.extendedProperties["private"].geolocation);
        return geolocation.address;
      } else {
        return null;
      }
    };

    Event.prototype.setGeolocation = function(lat, lng, address) {
      var _base, _base1, _ref, _ref1;
      if ((_ref = (_base = this.resource).extendedProperties) == null) {
        _base.extendedProperties = {};
      }
      if ((_ref1 = (_base1 = this.resource.extendedProperties)["private"]) == null) {
        _base1["private"] = {};
      }
      this.resource.extendedProperties["private"].geolocation = JSON.stringify({
        lat: lat,
        lng: lng,
        address: address
      });
      if (!((this.resource.location != null) && this.resource.location !== '')) {
        return this.resource.location = address;
      }
    };

    Event.prototype.update = function() {
      if (this.calendarId != null) {
        return gapi.client.calendar.events.update({
          calendarId: this.calendarId,
          eventId: this.resource.id,
          resource: this.resource
        }).execute(function(resp) {
          if (resp.error != null) {
            return console.error('gapi.client.calendar.events.update', resp);
          }
        });
      } else {
        return $('#modal-calendar').modal('show');
      }
    };

    Event.prototype.insert = function() {
      var _this = this;
      if (this.calendarId != null) {
        return gapi.client.calendar.events.insert({
          calendarId: this.calendarId,
          resource: this.resource
        }).execute(function(resp) {
          if (resp.error != null) {
            return console.error('gapi.client.calendar.events.update', resp);
          } else {
            return _this.resource = resp.result;
          }
        });
      } else {
        return $('#modal-calendar').modal('show');
      }
    };

    Event.prototype.geocode = function(callback) {
      var latLng, options,
        _this = this;
      if (Event.geocodeCount > 10) {
        console.log('too many geocoding requests');
        return false;
      }
      latLng = this.latLng();
      if (latLng != null) {
        options = {
          location: latLng
        };
      } else if (this.resource.location !== '') {
        options = {
          address: this.resource.location
        };
      } else {
        console.error('no hints for geocode');
        return;
      }
      geocoder.geocode(options, function(results, status) {
        switch (status) {
          case google.maps.GeocoderStatus.OK:
            if (results.length === 1) {
              _this.setGeolocation(results[0].geometry.location.lat(), results[0].geometry.location.lng(), results[0].formatted_address);
              _this.update();
            }
            return callback(results);
          case google.maps.GeocoderStatus.ZERO_RESULTS:
            return setTimeout((function() {
              return alert("" + _this.resource.location + "が見つかりません");
            }), 0);
          default:
            return console.error(status);
        }
      });
      return Event.geocodeCount += 1;
    };

    Event.prototype.setPlace = function(byClick) {
      var latLng, _ref;
      if (byClick == null) {
        byClick = false;
      }
      latLng = this.latLng();
      if (!latLng) {
        this.place = null;
        return null;
      }
      this.place = new Place({
        map: map,
        position: latLng,
        icon: (_ref = this.icon) != null ? _ref : null,
        shadow: this.icon != null ? Event.shadow : null,
        title: this.resource.location,
        animation: byClick ? google.maps.Animation.DROP : null
      }, this);
      return google.maps.event.addListener(this.place, 'animation_changed', function() {
        if (byClick) {
          return this.showInfo();
        }
      });
    };

    Event.prototype.tryToSetPlace = function(centering, byClick) {
      var _this = this;
      this.setPlace(byClick);
      if ((this.place != null) && centering) {
        map.setCenter(this.place.getPosition());
        currentPlace = this.place;
      }
      if (!((this.place != null) && (this.address() != null))) {
        return this.geocode(function(results) {
          var e, _i, _len, _ref;
          if (_this.place != null) {
            return _this.setGeolocation(results[0].geometry.location.lat(), results[0].geometry.location.lng(), results[0].formatted_address);
          } else if (results.length === 1) {
            _this.setPlace(byClick);
            if ((_this.place != null) && centering) {
              map.setCenter(_this.place.getPosition());
              return currentPlace = _this.place;
            }
          } else {
            _this.candidates = [];
            for (_i = 0, _len = results.length; _i < _len; _i++) {
              e = results[_i];
              _this.candidates.push(new Place({
                map: map,
                position: e.geometry.location,
                icon: (_ref = _this.icon) != null ? _ref : null,
                shadow: _this.icon != null ? Event.shadow : null,
                title: _this.resource.location + '?',
                optimized: false
              }, _this, e.formatted_address));
            }
            setTimeout((function() {
              return $("#map img[src=\"" + _this.icon.url + "\"]").addClass('candidate');
            }), 500);
            if (centering) {
              map.setCenter(_this.candidates[0].getPosition());
              return currentPlace = _this.candidates[0];
            }
          }
        });
      }
    };

    Event.prototype.setModal = function(place) {
      var e, endDeferred, i, setTime, startDeferred;
      modalPlace = place;
      Event.$modalInfo.find('input[name="summary"]').val(this.resource.summary);
      Event.$modalInfo.find('input[name="location"]').val(this.resource.location);
      if ((this.resource.start.date != null) && (this.resource.end.date != null)) {
        $('#form-event input[name="all-day"]')[0].checked = true;
        $('#form-event input[name="all-day"]').trigger('change');
        Event.$modalInfo.find('input[name="start-date"]').val(this.resource.start.date);
        Event.$modalInfo.find('input[name="end-date"]').val(this.resource.end.date);
      } else if ((this.resource.start.dateTime != null) && (this.resource.end.dateTime != null)) {
        setTime = function(startOrEnd) {
          var dateTime;
          dateTime = place.getDateTime(startOrEnd);
          Event.$modalInfo.find("input[name=\"" + startOrEnd + "-date\"]").val(dateTime.date);
          return Event.$modalInfo.find("input[name=\"" + startOrEnd + "-time\"]").val(dateTime.time);
        };
        $('#form-event input[name="all-day"]')[0].checked = false;
        $('#form-event input[name="all-day"]').trigger('change');
        startDeferred = $.Deferred();
        endDeferred = $.Deferred();
        $.when(startDeferred, endDeferred).then(function() {
          return spinner.stop();
        });
        spinner.spin(document.body);
        if (place.startTimeZone != null) {
          startDeferred.resolve();
          setTime('start');
        } else {
          getTimeZone(new Date(this.resource.start.dateTime), place.getPosition(), function(obj) {
            startDeferred.resolve();
            place.startTimeZone = obj;
            return setTime('start');
          });
        }
        if (place.endTimeZone != null) {
          endDeferred.resolve();
          setTime('end');
        } else {
          getTimeZone(new Date(this.resource.end.dateTime), place.getPosition(), function(obj) {
            endDeferred.resolve();
            place.endTimeZone = obj;
            return setTime('end');
          });
        }
      } else {
        console.error('inconsistent start and end');
      }
      if (this.candidates != null) {
        $('#candidate').css('display', 'block');
        $('#candidate select[name="candidate"]').html(((function() {
          var _i, _len, _ref, _results;
          _ref = this.candidates;
          _results = [];
          for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
            e = _ref[i];
            _results.push("<option value=\"" + i + "\" " + (e === place ? 'selected' : '') + ">" + e.address + "</option>");
          }
          return _results;
        }).call(this)).join(''));
      } else {
        $('#candidate').css('display', 'none');
      }
      return Event.$modalInfo.find('input[name="description"]').val(this.resource.description);
    };

    return Event;

  })();

  initializeDOM = function() {
    var $calendarList;
    localize();
    $('#container').css('display', '');
    new FastClick(document.body);
    $('#button-authorize').on('click', function() {
      return gapi.auth.authorize({
        'client_id': CLIENT_ID,
        'scope': SCOPES,
        'immediate': false
      }, handleAuthResult);
    });
    $calendarList = $('#calendar-list');
    $('#modal-calendar').on('show', function(event) {
      var req;
      req = gapi.client.calendar.calendarList.list();
      return req.execute(function(resp) {
        var e;
        if (resp.error != null) {
          return console.error(resp);
        } else {
          calendars = resp.items;
          return $calendarList.html('<option value="new">新規作成</option>' + ((function() {
            var _i, _len, _results;
            _results = [];
            for (_i = 0, _len = calendars.length; _i < _len; _i++) {
              e = calendars[_i];
              _results.push("<option value=\"" + e.id + "\">" + e.summary + "</option>");
            }
            return _results;
          })()).join(''));
        }
      });
    });
    $('#button-show').on('click', function() {
      var e, id, name, options, req, _i, _j, _len, _len1, _ref;
      if (Event.events.length > 0 && (Event.events[0].calendarId != null)) {
        Event.clearAll();
      }
      id = $calendarList.children('option:selected').attr('value');
      if (id === 'new') {
        if (name = prompt('新しいカレンダーに名前をつけてください')) {
          req = gapi.client.calendar.calendars.insert({
            resource: {
              summary: name
            }
          });
          return req.execute(function(resp) {
            var e, _i, _len, _ref, _results;
            if (resp.error != null) {
              return alert('カレンダーが作成できませんでした');
            } else {
              currentCalendar = resp.result;
              calendars.push(currentCalendar);
              _ref = Event.events;
              _results = [];
              for (_i = 0, _len = _ref.length; _i < _len; _i++) {
                e = _ref[_i];
                _results.push(e.calendarId = currentCalendar.id);
              }
              return _results;
            }
          });
        }
      } else {
        for (_i = 0, _len = calendars.length; _i < _len; _i++) {
          e = calendars[_i];
          if (e.id === id) {
            currentCalendar = e;
            break;
          }
        }
        _ref = Event.events;
        for (_j = 0, _len1 = _ref.length; _j < _len1; _j++) {
          e = _ref[_j];
          e.calendarId = currentCalendar.id;
        }
        options = {
          calendarId: id
        };
        if ($('#form-calendar [name="start-date"]')[0].value !== '') {
          options.timeMin = $('#form-calendar [name="start-date"]')[0].value + 'T00:00:00Z';
        }
        if ($('#form-calendar [name="end-date"]')[0].value !== '') {
          options.timeMax = $('#form-calendar [name="end-date"]')[0].value + 'T00:00:00Z';
        }
        req = gapi.client.calendar.events.list(options);
        return req.execute(function(resp) {
          var event, i, _k, _len2, _ref1, _ref2, _results;
          if (resp.error != null) {
            return console.error(resp);
          } else if (((_ref1 = resp.items) != null ? _ref1.length : void 0) > 0) {
            resp.items.sort(compareEventResources);
            Event.geocodeCount = 0;
            _ref2 = resp.items;
            _results = [];
            for (i = _k = 0, _len2 = _ref2.length; _k < _len2; i = ++_k) {
              e = _ref2[i];
              _results.push(event = new Event(id, e));
            }
            return _results;
          }
        });
      }
    });
    $('#button-confirm').on('click', function() {
      var candidate, candidateIndex, position;
      candidateIndex = parseInt($('#form-event input[name="candidate"]').val());
      candidate = modalPlace.event.candidates[candidateIndex];
      position = candidate.getPosition();
      modalPlace.event.setGeolocation(position.lat(), position.lng(), candidate.address);
      modalPlace.event.update();
      modalPlace.event.clearMarkers();
      modalPlace.event.setPlace();
      return $('#candidate').css('display', 'none');
    });
    $('#button-update').on('click', function() {
      var anEvent, endDateTime, startDateTime, timeZone, updateFlag;
      anEvent = modalPlace.event;
      if (anEvent.resource.id != null) {
        updateFlag = false;
        if (anEvent.resource.summary !== $('#form-event input[name="summary"]').val()) {
          updateFlag = true;
          anEvent.resource.summary = $('#form-event input[name="summary"]').val();
        }
        if (anEvent.resource.location !== $('#form-event input[name="location"]').val()) {
          updateFlag = true;
          anEvent.resource.location = $('#form-event input[name="location"]').val();
          delete anEvent.resource.extendedProperties["private"].geolocation;
        }
        if ($('#form-event input[name="all-day"]')[0].checked) {
          if (anEvent.resource.start.date !== $('#form-event input[name="start-date"]').val().replace(/-/g, '/')) {
            updateFlag = true;
            delete anEvent.resource.start.dateTime;
            anEvent.resource.start.date = $('#form-event input[name="start-date"]').val().replace(/-/g, '/');
          }
          if (anEvent.resource.end.date !== $('#form-event input[name="end-date"]').val().replace(/-/g, '/')) {
            updateFlag = true;
            delete anEvent.resource.end.dateTime;
            anEvent.resource.end.date = $('#form-event input[name="end-date"]').val().replace(/-/g, '/');
          }
        } else {
          timeZone = modalPlace.startTimeZone;
          startDateTime = new Date($('#form-event input[name="start-date"]').val().replace(/-/g, '/') + ' ' + $('#form-event input[name="start-time"]').val() + timeDifference(timeZone.dstOffset + timeZone.rawOffset));
          if (new Date(anEvent.resource.start.dateTime).getTime() !== startDateTime.getTime()) {
            updateFlag = true;
            delete anEvent.resource.start.date;
            anEvent.resource.start.dateTime = startDateTime.toISOString();
            anEvent.resource.start.timeZone = timeZone.timeZoneId;
          }
          timeZone = modalPlace.endTimeZone;
          endDateTime = new Date($('#form-event input[name="end-date"]').val().replace(/-/g, '/') + ' ' + $('#form-event input[name="end-time"]').val() + timeDifference(timeZone.dstOffset + timeZone.rawOffset));
          if (new Date(anEvent.resource.end.dateTime).getTime() !== endDateTime.getTime()) {
            updateFlag = true;
            delete anEvent.resource.end.date;
            anEvent.resource.end.dateTime = endDateTime.toISOString();
            anEvent.resource.end.timeZone = timeZone.timeZoneId;
          }
        }
        if (anEvent.resource.description !== $('#form-event input[name="description"]').val()) {
          updateFlag = true;
          anEvent.resource.description = $('#form-event input[name="description"]').val();
        }
        if (updateFlag) {
          return anEvent.update();
        }
      } else {
        return anEvent.insert();
      }
    });
    $('#modal-info').on('hide', function() {
      return spinner.stop();
    });
    $('#form-event input[name="all-day"]').on('change', function() {
      $('#form-event input[name="start-time"]').css('display', this.checked ? 'none' : '');
      return $('#form-event input[name="end-time"]').css('display', this.checked ? 'none' : '');
    });
    $('#button-delete').on('click', function() {
      var anEvent, req;
      anEvent = modalPlace.event;
      if ((anEvent.calendarId != null) && (anEvent.resource.id != null)) {
        req = gapi.client.calendar.events["delete"]({
          calendarId: anEvent.calendarId,
          eventId: anEvent.resource.id
        });
        req.execute(function(resp) {
          if (resp.error != null) {
            return alert('予定が削除できませんでした');
          }
        });
      }
      Event.events.splice(Event.events.indexOf(anEvent, 1));
      anEvent.clearMarkers();
      return modalPlace = null;
    });
    $('#button-prev, #button-next').on('click', function() {
      var candidateIndex, eventIndex, sorted, _ref, _ref1, _ref2, _ref3;
      if (directions != null) {
        if (this.id === 'buttion-prev') {
          directions.routeIndex -= 1;
          if (directions.routeIndex < 0) {
            directions.index -= 1;
            if (directions.index < 0) {
              directions.index = directions.results.length - 1;
            }
            directionsRenderer.setDirections(directions.results[directions.index]);
            directions.routeIdex = directions.results[directions.index].routes.length - 1;
          }
        } else {
          directions.routeIndex += 1;
          if (directions.routeIndex >= directions.results[directions.index].routes.length) {
            directions.index += 1;
            if (directions.index >= directions.results.length) {
              directions.index = 0;
            }
            directionsRenderer.setDirections(directions.results[directions.index]);
            directions.routeIdex = 0;
          }
        }
        return directionsRenderer.setRouteIndex(directions.routeIdex);
      } else {
        sorted = Event.events.sort(function(x, y) {
          return compareEventResources(x.resource, y.resource);
        });
        if (currentPlace != null) {
          eventIndex = sorted.indexOf(currentPlace.event);
          if (Event.events[eventIndex].candidates != null) {
            candidateIndex = Event.events[eventIndex].candidates.indexOf(currentPlace);
            if (this.id === 'button-prev') {
              candidateIndex -= 1;
              if (candidateIndex < 0) {
                candidateIndex = null;
              }
            } else {
              candidateIndex += 1;
              if (candidateIndex >= Event.events[eventIndex].candidates.length) {
                candidateIndex = null;
              }
            }
          }
          if (candidateIndex != null) {
            currentPlace = Event.events[eventIndex].candidates[candidateIndex];
          } else {
            if (this.id === 'button-prev') {
              eventIndex -= 1;
              if (eventIndex < 0) {
                eventIndex = sorted.length - 1;
              }
              candidateIndex = ((_ref = Event.events[eventIndex].candidates) != null ? _ref.length : void 0) - 1;
            } else {
              eventIndex += 1;
              if (eventIndex >= sorted.length) {
                eventIndex = 0;
              }
              candidateIndex = 0;
            }
            currentPlace = (_ref1 = sorted[eventIndex].place) != null ? _ref1 : sorted[eventIndex].candidates[candidateIndex];
          }
        } else if (this.id === 'button-next') {
          currentPlace = (_ref2 = sorted[0].place) != null ? _ref2 : sorted[0].candidates[0];
        } else {
          console.log(sorted[sorted.length - 1]);
          currentPlace = (_ref3 = sorted[sorted.length - 1].place) != null ? _ref3 : sorted[sorted.length - 1].candidates[sorted[sorted.length - 1].candidates.length - 1];
        }
        return map.setCenter(currentPlace.getPosition());
      }
    });
    $('#button-direction').on('click', function(event) {
      originPlace = modalPlace;
      return alert('ここからの道順を調べます。目的地のマーカをクリックしてください');
    });
    $('#candidate select[name="candidate"]').on('change', function(event) {
      modalPlace = modalPlace.event.candidates[parseInt(this.value)];
      return map.setCenter(modalPlace.getPosition());
    });
    return $('#button-search').on('click', function(event) {
      var location;
      location = $('#form-event input[name="location"]').val();
      modalPlace.event.clearMarkers();
      modalPlace.event.tryToSetPlace(true, false);
      return modalPlace = currentPlace;
    });
  };

  initializeGoogleMaps = function() {
    var mapOptions, mapStatus;
    mapOptions = {
      mapTypeId: google.maps.MapTypeId.ROADMAP,
      disableDefaultUI: /iPad|iPhone/.test(navigator.userAgent),
      zoomControlOptions: {
        position: google.maps.ControlPosition.LEFT_CENTER
      },
      panControlOptions: {
        position: google.maps.ControlPosition.LEFT_CENTER
      }
    };
    if (localStorage[MAP_STATUS] != null) {
      mapStatus = JSON.parse(localStorage[MAP_STATUS]);
      mapOptions.center = new google.maps.LatLng(mapStatus.lat, mapStatus.lng);
      mapOptions.zoom = mapStatus.zoom;
    } else {
      mapOptions.center = new google.maps.LatLng(35.660389, 139.729225);
      mapOptions.zoom = 14;
    }
    map = new google.maps.Map(document.getElementById('map'), mapOptions);
    map.setTilt(45);
    google.maps.event.addListener(map, 'click', function(event) {
      return new Event(currentCalendar != null ? currentCalendar.id : void 0, {
        extendedProperties: {
          "private": {
            geolocation: JSON.stringify({
              lat: event.latLng.lat(),
              lng: event.latLng.lng()
            })
          }
        }
      }, false, true);
    });
    geocoder = new google.maps.Geocoder();
    return directionsRenderer = new google.maps.DirectionsRenderer({
      hideRouteList: false,
      map: map,
      panel: $('#directions-panel')[0]
    });
  };

  window.app = {
    initialize: function() {
      initializeGoogleMaps();
      return initializeDOM();
    },
    saveMapStatus: saveMapStatus
  };

  window.handleClientLoad = function() {
    return setTimeout((function() {
      return gapi.auth.authorize({
        'client_id': CLIENT_ID,
        'scope': SCOPES,
        'immediate': true
      }, handleAuthResult);
    }), 1);
  };

}).call(this);
