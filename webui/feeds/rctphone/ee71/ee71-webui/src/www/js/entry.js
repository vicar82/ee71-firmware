// esbuild entry point — bundles all JS in correct load order
// Vendor libraries (uPlot, termino) are loaded as plain <script> tags in
// index.html, NOT bundled: both are IIFE scripts that assign a bare
// `var uPlot = ...` / `var Termino = ...`, which stays module-local inside
// the esbuild bundle and never reaches window.
// Core
import './api.js';
import './i18n.js';
import './app-core.js';
// Pages (order doesn't matter — each registers via App.registerPage)
import './pages/login.js';
import './pages/dashboard.js';
import './pages/connection.js';
import './pages/apn.js';
import './pages/at-terminal.js';
import './pages/clients.js';
import './pages/power.js';
import './pages/wifi.js';
import './pages/lan.js';
import './pages/firewall.js';
import './pages/upnp.js';
import './pages/ttl-fix.js';
import './pages/sms.js';
import './pages/ussd.js';
import './pages/bands.js';
import './pages/vpn.js';
import './pages/diagnostics.js';
import './pages/speedtest.js';
import './pages/settings.js';
import './pages/ssh.js';
import './pages/backup.js';
import './pages/about.js';
import './pages/mobile-settings.js';
// Boot (must be last — calls App.init on DOMContentLoaded)
import './app-boot.js';
