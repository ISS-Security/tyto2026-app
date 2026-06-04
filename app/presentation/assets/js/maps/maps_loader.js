// Globals shared by the map init scripts (attendance_map.js, location_form.js).
// Externalized from an inline <script> block so the CSP can keep script_src
// strict ('self' + pinned CDNs) without 'unsafe-inline'.
window.TytoMaps = {
  OSM_TILE_URL: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  OSM_ATTRIBUTION: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
  DEFAULT_CENTER: [24.7956, 120.9966], // NTHU campus
  DEFAULT_ZOOM: 16
};
window.addEventListener('error', function(event) {
  if (event && event.target && event.target.src && event.target.src.indexOf('leaflet.js') !== -1) {
    window.dispatchEvent(new CustomEvent('leaflet:unavailable'));
  }
}, true);
setTimeout(function() {
  if (typeof L === 'undefined') {
    window.dispatchEvent(new CustomEvent('leaflet:unavailable'));
  }
}, 3000);
