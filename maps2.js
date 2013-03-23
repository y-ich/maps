// Generated by CoffeeScript 1.6.1
(function() {
  var CLIENT_ID, MAP_STATUS, MarkerWithCircle, MobileInfoWindow, SCOPES, checkAuth, foo, fusionTablesLayers, getLocalizedString, handleAuthResult, handleClientLoad, initializeDOM, initializeGoogleMaps, localize, map, method, name, saveMapStatus, searchFiles, setLocalExpressionInto, _ref,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  CLIENT_ID = '458982307818.apps.googleusercontent.com';

  SCOPES = ['https://www.googleapis.com/auth/drive', 'https://www.googleapis.com/auth/fusiontables.readonly'];

  handleClientLoad = function() {
    return window.setTimeout(checkAuth(true), 1);
  };

  checkAuth = function(immediate) {
    return function() {
      return gapi.auth.authorize({
        'client_id': CLIENT_ID,
        'scope': SCOPES,
        'immediate': immediate
      }, handleAuthResult);
    };
  };

  handleAuthResult = function(authResult) {
    if (authResult && !authResult.error) {
      console.log('ok');
      gapi.client.load('drive', 'v2', function() {
        $('#button-google-drive').css('display', 'none');
        return $('#button-fusion-tables').css('display', '');
      });
      return gapi.client.load('fusiontables', 'v1');
    } else {
      console.log('ng');
      return $('#button-google-drive').text('Google Drive').attr('disabled', null);
    }
  };

  searchFiles = function(query, callback) {
    var initialRequest, retrievePageOfFiles;
    retrievePageOfFiles = function(request, result) {
      return request.execute(function(resp) {
        var nextPageToken;
        result = result.concat(resp.items);
        nextPageToken = resp.nextPageToken;
        if (nextPageToken) {
          request = gapi.client.drive.files.list({
            'pageToken': nextPageToken
          });
          return retrievePageOfFiles(request, result);
        } else {
          return callback(result);
        }
      });
    };
    initialRequest = gapi.client.drive.files.list({
      q: query
    });
    return retrievePageOfFiles(initialRequest, []);
  };

  foo = function(callback) {
    var base64Data, boundary, close_delim, contentType, delimiter, metadata, multipartRequestBody, request;
    boundary = '-------314159265358979323846';
    delimiter = "\r\n--" + boundary + "\r\n";
    close_delim = "\r\n--" + boundary + "--";
    contentType = fileData.type || 'application/octet-stream';
    metadata = {
      'title': fileData.name,
      'mimeType': contentType
    };
    base64Data = btoa(reader.result);
    multipartRequestBody = delimiter + 'Content-Type: application/json\r\n\r\n' + JSON.stringify(metadata) + delimiter + 'Content-Type: ' + contentType + '\r\n' + 'Content-Transfer-Encoding: base64\r\n' + '\r\n' + base64Data + close_delim;
    request = gapi.client.request({
      'path': '/upload/drive/v2/files',
      'method': 'POST',
      'params': {
        'uploadType': 'multipart'
      },
      'headers': {
        'Content-Type': 'multipart/mixed; boundary="' + boundary + '"'
      },
      'body': multipartRequestBody
    });
    if (!callback) {
      callback = function(file) {
        return console.log(file);
      };
    }
    return request.execute(callback);
  };

  window.handleClientLoad = handleClientLoad;

  MobileInfoWindow = (function(_super) {

    __extends(MobileInfoWindow, _super);

    function MobileInfoWindow(options) {
      this.setOptions(options);
    }

    MobileInfoWindow.prototype.getContent = function() {
      return this.content;
    };

    MobileInfoWindow.prototype.getPosition = function() {
      return this.position;
    };

    MobileInfoWindow.prototype.getZIndex = function() {
      return this.zIndex;
    };

    MobileInfoWindow.prototype.setContent = function(content) {
      this.content = content;
      if (this.element == null) {
        this.element = document.createElement('div');
        if (this.maxWidth) {
          this.element.style['max-width'] = this.maxWidth + 'px';
        }
        this.element.className = 'info-window';
      }
      if (typeof this.content === 'string') {
        this.element.innerHTML = this.content;
      } else {
        this.element.innerHTML = '';
        this.element.appendChild(this.content);
      }
      return google.maps.event.trigger(this, 'content_changed');
    };

    MobileInfoWindow.prototype.setPosition = function(position) {
      this.position = position;
      return google.maps.event.trigger(this, 'position_changed');
    };

    MobileInfoWindow.prototype.setZIndex = function(zIndex) {
      this.zIndex = zIndex;
      this.element.style['z-index'] = this.zIndex.toString();
      return google.maps.event.trigger(this, 'zindex_changed');
    };

    MobileInfoWindow.prototype.close = function() {
      return this.setMap(null);
    };

    MobileInfoWindow.prototype.open = function(map, anchor) {
      var icon, markerAnchor, markerSize, _ref;
      this.anchor = anchor;
      if (anchor != null) {
        this.setPosition(this.anchor.getPosition());
        icon = this.anchor.getIcon();
        if (icon != null) {
          markerSize = icon.size;
          markerAnchor = (_ref = icon.anchor) != null ? _ref : new google.maps.Point(Math.floor(markerSize.width / 2), markerSize.height);
        } else {
          markerSize = new google.maps.Size(DEFAULT_ICON_SIZE, DEFAULT_ICON_SIZE);
          markerAnchor = new google.maps.Point(DEFAULT_ICON_SIZE / 2, DEFAULT_ICON_SIZE);
        }
        this.pixelOffset = new google.maps.Size(Math.floor(markerSize.width / 2) - markerAnchor.x, -markerAnchor.y, 'px', 'px');
      }
      return this.setMap(map);
    };

    MobileInfoWindow.prototype.setOptions = function(options) {
      var _ref, _ref1, _ref2, _ref3, _ref4, _ref5;
      this.maxWidth = (_ref = options.maxWidth) != null ? _ref : null;
      this.setContent((_ref1 = options.content) != null ? _ref1 : '');
      this.disableAutoPan = (_ref2 = options.disableAutoPan) != null ? _ref2 : null;
      this.pixelOffset = (_ref3 = options.pixelOffset) != null ? _ref3 : new google.maps.Size(0, 0, 'px', 'px');
      this.setPosition((_ref4 = options.position) != null ? _ref4 : null);
      return this.setZIndex((_ref5 = options.zIndex) != null ? _ref5 : 0);
    };

    MobileInfoWindow.prototype.onAdd = function() {
      this.getPanes().floatPane.appendChild(this.element);
      return google.maps.event.trigger(this, 'domready');
    };

    MobileInfoWindow.prototype.draw = function() {
      var xy;
      xy = this.getProjection().fromLatLngToDivPixel(this.getPosition());
      this.element.style.left = xy.x + this.pixelOffset.width - this.element.offsetWidth / 2 + 'px';
      return this.element.style.top = xy.y + this.pixelOffset.height - this.element.offsetHeight + 'px';
    };

    MobileInfoWindow.prototype.onRemove = function() {
      return this.element.parentNode.removeChild(this.element);
    };

    return MobileInfoWindow;

  })(google.maps.OverlayView);

  MarkerWithCircle = (function() {

    function MarkerWithCircle(options) {
      var _ref, _ref1, _ref2,
        _this = this;
      this.marker = new google.maps.Marker(options);
      this.pulse = new google.maps.Circle({
        center: options.position,
        clickable: false,
        map: (_ref = options.map) != null ? _ref : null,
        visible: (_ref1 = options.visible) != null ? _ref1 : true,
        zIndex: (_ref2 = options.zIndex) != null ? _ref2 : null,
        fillColor: '#06f',
        fillOpacity: 0.1,
        strokeColor: '#06f',
        strokeOpacity: 0.5,
        strokeWeight: 2
      });
      if (!((options.clickable != null) && !options.clickable)) {
        google.maps.event.addListener(this.marker, 'click', function() {
          return google.maps.event.trigger(_this, 'click');
        });
      }
    }

    MarkerWithCircle.prototype.setPosition = function(latLng) {
      this.marker.setPosition(latLng);
      return this.pulse.setCenter(latLng);
    };

    MarkerWithCircle.prototype.setVisible = function(visible) {
      this.marker.setVisible(visible);
      return this.pulse.setVisible(visible);
    };

    MarkerWithCircle.prototype.setMap = function(map) {
      this.marker.setMap(map);
      return this.pulse.setMap(map);
    };

    MarkerWithCircle.prototype.setRadius = function(radius) {
      return this.pulse.setRadius(radius);
    };

    return MarkerWithCircle;

  })();

  _ref = google.maps.Marker.prototype;
  for (name in _ref) {
    method = _ref[name];
    if (typeof method === 'function') {
      if (!MarkerWithCircle.prototype[name]) {
        MarkerWithCircle.prototype[name] = (function(name) {
          return function() {
            return this.marker[name]();
          };
        })(name);
      }
    }
  }

  MAP_STATUS = 'maps2-map-status';

  map = null;

  fusionTablesLayers = [];

  getLocalizedString = function(key) {
    var _ref1;
    if (typeof localizedStrings !== "undefined" && localizedStrings !== null) {
      return (_ref1 = localizedStrings[key]) != null ? _ref1 : key;
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
    document.title = getLocalizedString('Maps');
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

  initializeDOM = function() {
    var $fusionTables;
    localize();
    $('#container').css('display', '');
    $('#button-google-drive').on('click', checkAuth(false));
    $fusionTables = $('#fusion-tables');
    $('#modal-fusion-tables').on('show', function(event) {
      return searchFiles('mimeType = "application/vnd.google-apps.fusiontable" and trashed = false', function(result) {
        var checked, e;
        checked = function(column) {
          if ($fusionTables.find("input[value=" + column.id + "]:checked").length > 0) {
            return 'checked';
          } else {
            return '';
          }
        };
        return $fusionTables.html(((function() {
          var _i, _len, _ref1, _results;
          _ref1 = result.filter(function(e) {
            return e.shared;
          });
          _results = [];
          for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
            e = _ref1[_i];
            _results.push("<label><input type=\"checkbox\" value=\"" + e.id + "\" " + (checked(e)) + "/>" + e.title + "</label>");
          }
          return _results;
        })()).join(''));
      });
    });
    return $('#button-show').on('click', function(event) {
      var e, req, _i, _j, _len, _len1, _ref1, _results;
      for (_i = 0, _len = fusionTablesLayers.length; _i < _len; _i++) {
        e = fusionTablesLayers[_i];
        e.setMap(null);
      }
      fusionTablesLayers = [];
      _ref1 = $('#fusion-tables input:checked:lt(5)');
      _results = [];
      for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
        e = _ref1[_j];
        req = gapi.client.fusiontables.column.list({
          tableId: e.value
        });
        _results.push(req.execute(function(result) {
          var locations, option;
          if (result.error != null) {
            return console.error(result.error);
          } else {
            locations = result.items.filter(function(e) {
              return e.type === 'LOCATION';
            });
            if (locations.length > 0) {
              option = {
                map: map,
                query: {
                  from: e.value,
                  select: locations[0].name
                },
                styles: [
                  {
                    markerOptions: {
                      iconName: 'red_stars'
                    }
                  }
                ]
              };
              return fusionTablesLayers.push(new google.maps.FusionTablesLayer(option));
            } else {
              return console.error('no locations');
            }
          }
        }));
      }
      return _results;
    });
  };

  initializeGoogleMaps = function() {
    var mapOptions, mapStatus;
    mapOptions = {
      mapTypeId: google.maps.MapTypeId.ROADMAP,
      disableDefaultUI: true,
      streetView: new google.maps.StreetViewPanorama(document.getElementById('streetview'), {
        panControl: false,
        zoomControl: false,
        visible: false
      })
    };
    google.maps.event.addListener(mapOptions.streetView, 'position_changed', function() {
      return map.setCenter(this.getPosition());
    });
    if (localStorage[MAP_STATUS] != null) {
      mapStatus = JSON.parse(localStorage[MAP_STATUS]);
      mapOptions.center = new google.maps.LatLng(mapStatus.lat, mapStatus.lng);
      mapOptions.zoom = mapStatus.zoom;
    } else {
      mapOptions.center = new google.maps.LatLng(35.660389, 139.729225);
      mapOptions.zoom = 14;
    }
    map = new google.maps.Map(document.getElementById('map'), mapOptions);
    return map.setTilt(45);
  };

  window.app = {
    initialize: function() {
      initializeGoogleMaps();
      return initializeDOM();
    },
    saveMapStatus: saveMapStatus
  };

}).call(this);
