// Compact per-event map showing the event location + student's current
// position. Initializes every container carrying data-attendance-map
// attributes (page data travels via data-* -- no inline scripts under CSP).
// Browser geolocation consent prompt fires on load and on "Retry";
// on denial, inline error + explicit Retry button. No manual-coord bypass
// (would defeat the geofence the API enforces).
(function() {
  function initAttendanceMap(mapEl) {
    var eventId = mapEl.getAttribute('data-event-id');
    var locLat = parseFloat(mapEl.getAttribute('data-lat'));
    var locLon = parseFloat(mapEl.getAttribute('data-lon'));
    var errEl = document.getElementById('attendance-map-error-' + eventId);
    if (typeof L === 'undefined') {
      mapEl.classList.add('d-none');
      return;
    }
    var map = L.map(mapEl).setView([locLat, locLon], 17);
    L.tileLayer(window.TytoMaps.OSM_TILE_URL, {
      attribution: window.TytoMaps.OSM_ATTRIBUTION, maxZoom: 19
    }).addTo(map);
    L.marker([locLat, locLon]).addTo(map).bindPopup('Event location').openPopup();

    var myMarker = null;
    function showError(msg) {
      errEl.querySelector('span').textContent = msg;
      errEl.classList.remove('d-none');
    }
    function locate() {
      errEl.classList.add('d-none');
      if (!navigator.geolocation) {
        showError('Geolocation is not supported by this browser.');
        return;
      }
      navigator.geolocation.getCurrentPosition(
        function(position) {
          var myLat = position.coords.latitude;
          var myLon = position.coords.longitude;
          // Feed the check-in form so submit sends coords without re-prompting.
          var form = document.getElementById('checkin-form-' + eventId);
          if (form) {
            var lonEl = form.querySelector('input[name="longitude"]');
            var latEl = form.querySelector('input[name="latitude"]');
            if (lonEl) { lonEl.value = myLon; }
            if (latEl) { latEl.value = myLat; }
          }
          if (myMarker) {
            myMarker.setLatLng([myLat, myLon]);
          } else {
            myMarker = L.marker([myLat, myLon], { opacity: 0.7 })
              .addTo(map).bindPopup('You are here');
          }
        },
        function(err) {
          if (err.code === 1) {
            showError('Check-in requires location permission — adjust in browser site settings.');
          } else {
            showError('Location access required to check in.');
          }
        }
      );
    }
    locate();
    Array.prototype.forEach.call(
      document.querySelectorAll('.attendance-retry-btn[data-event-id="' + eventId + '"]'),
      function(btn) { btn.addEventListener('click', locate); }
    );
  }

  Array.prototype.forEach.call(
    document.querySelectorAll('[data-attendance-map]'), initAttendanceMap
  );
})();
