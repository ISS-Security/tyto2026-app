// Location-placement map for the "Add location" form: click to drop a
// draggable marker, or geolocate. Falls back to manual coordinate entry
// when Leaflet is unavailable. Initializes only when the page has the
// #location-map container.
(function() {
  var mapDiv = document.getElementById('location-map');
  if (!mapDiv) { return; }

  var latInput = document.getElementById('input-latitude');
  var lonInput = document.getElementById('input-longitude');
  var display = document.getElementById('coords-display');
  var fallbackLat = document.getElementById('fallback-latitude');
  var fallbackLon = document.getElementById('fallback-longitude');
  var fallbackDiv = document.getElementById('map-fallback');
  var marker = null;
  var map = null;

  function setCoords(lat, lon) {
    latInput.value = lat;
    lonInput.value = lon;
    display.textContent = 'Lat ' + parseFloat(lat).toFixed(6) + ', Lon ' + parseFloat(lon).toFixed(6);
  }

  function placeMarker(lat, lon) {
    if (!map) return;
    if (marker) {
      marker.setLatLng([lat, lon]);
    } else {
      marker = L.marker([lat, lon], { draggable: true }).addTo(map);
      marker.on('dragend', function(e) {
        var pos = e.target.getLatLng();
        setCoords(pos.lat, pos.lng);
      });
    }
    setCoords(lat, lon);
  }

  function initMap() {
    var center = window.TytoMaps.DEFAULT_CENTER;
    var initialLat = parseFloat(latInput.value);
    var initialLon = parseFloat(lonInput.value);
    if (!isNaN(initialLat) && !isNaN(initialLon)) {
      center = [initialLat, initialLon];
    }
    map = L.map('location-map').setView(center, window.TytoMaps.DEFAULT_ZOOM);
    L.tileLayer(window.TytoMaps.OSM_TILE_URL, {
      attribution: window.TytoMaps.OSM_ATTRIBUTION,
      maxZoom: 19
    }).addTo(map);
    map.on('click', function(e) {
      placeMarker(e.latlng.lat, e.latlng.lng);
    });
    if (!isNaN(initialLat) && !isNaN(initialLon)) {
      placeMarker(initialLat, initialLon);
    }
  }

  function showFallback() {
    mapDiv.classList.add('d-none');
    fallbackDiv.classList.remove('d-none');
    var sync = function() { setCoords(fallbackLat.value, fallbackLon.value); };
    fallbackLat.addEventListener('change', sync);
    fallbackLon.addEventListener('change', sync);
  }

  if (typeof L === 'undefined') {
    window.addEventListener('leaflet:unavailable', showFallback);
    // Belt-and-suspenders: if L never appears within 4s, fallback now.
    setTimeout(function() { if (typeof L === 'undefined') showFallback(); }, 4000);
  } else {
    initMap();
  }

  document.getElementById('get-location-btn').addEventListener('click', function() {
    if (!navigator.geolocation) {
      alert('Geolocation is not supported by this browser.');
      return;
    }
    navigator.geolocation.getCurrentPosition(
      function(position) {
        var lat = position.coords.latitude;
        var lon = position.coords.longitude;
        placeMarker(lat, lon);
        if (map) map.setView([lat, lon], 17);
      },
      function(err) {
        alert('Location permission denied or unavailable: ' + err.message);
      }
    );
  });
})();
