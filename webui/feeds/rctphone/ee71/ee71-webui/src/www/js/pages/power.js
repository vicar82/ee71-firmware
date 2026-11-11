;(function() {
    'use strict';
    var $ = App.$, $$ = App.$$, icon = App.icon, escHtml = App.escHtml;
    var _timer = null;

    // Простейший SVG-график истории тока (без uPlot — точек мало, ось времени
    // нелинейная после перезагрузки, честнее рисовать сами).
    function renderGraph(points) {
        if (!points || points.length < 2) return '<p class="text-muted">История появится через несколько минут работы логгера (cron раз в минуту).</p>';
        var w = 640, h = 140, pad = 8;
        var mas = points.map(function(p) { return p[1]; });
        var max = Math.max.apply(null, mas.concat([50]));
        var min = Math.min.apply(null, mas.concat([0]));
        var span = (max - min) || 1;
        var step = (w - 2 * pad) / (points.length - 1);
        var pts = points.map(function(p, i) {
            var x = pad + i * step;
            var y = h - pad - ((p[1] - min) / span) * (h - 2 * pad);
            return x.toFixed(1) + ',' + y.toFixed(1);
        }).join(' ');
        return '<svg viewBox="0 0 ' + w + ' ' + h + '" style="width:100%;height:auto">' +
            '<polyline points="' + pts + '" fill="none" stroke="currentColor" stroke-width="1.5"/>' +
            '<text x="' + pad + '" y="' + (pad + 8) + '" font-size="9">' + max + ' mA</text>' +
            '<text x="' + pad + '" y="' + (h - pad) + '" font-size="9">' + min + ' mA</text>' +
            '</svg>';
    }

    function loadHist() {
        return API.cgiGet('power.cgi', { action: 'hist' }).then(function(r) {
            var el = $('#power-graph');
            if (el) el.innerHTML = renderGraph(r.points || []);
        }).catch(function() {});
    }

    function loadSnap() {
        return API.cgiGet('power.cgi', { action: 'snap' }).then(function(s) {
            function set(id, v) { var e = $(id); if (e) e.textContent = v; }
            set('#power-ma', s.ma + ' mA');
            set('#power-mv', (s.mv / 1000).toFixed(3) + ' V');
            set('#power-mw', s.mw + ' mW');
            set('#power-cap', (s.cap || '—') + '%');
            set('#power-status', s.on_battery ? 'Батарея' : (s.status || 'USB'));
            var badge = $('#power-src');
            if (badge) badge.className = 'badge ' + (s.on_battery ? 'badge-warn' : 'badge-ok');
        }).catch(function() {});
    }

    function renderPower(container) {
        container.innerHTML =
            '<h2>Питание</h2>' +
            '<div class="card"><div class="stat-grid">' +
            '<div class="stat-row"><span class="label">Источник</span><span class="value" id="power-src"><span id="power-status">—</span></span></div>' +
            '<div class="stat-row"><span class="label">Ток</span><span class="value text-mono" id="power-ma">—</span></div>' +
            '<div class="stat-row"><span class="label">Напряжение</span><span class="value text-mono" id="power-mv">—</span></div>' +
            '<div class="stat-row"><span class="label">Мощность</span><span class="value text-mono" id="power-mw">—</span></div>' +
            '<div class="stat-row"><span class="label">Заряд</span><span class="value text-mono" id="power-cap">—</span></div>' +
            '</div>' +
            '<p class="text-small text-muted" style="margin-top:8px">Для замера разряда вытащи USB-кабель: «Ток» покажет потребление от батареи. Логгер пишет раз в минуту (12 ч истории).</p>' +
            '</div>' +
            '<div class="card"><h3>История тока (12 ч)</h3><div id="power-graph">…</div></div>';

        loadSnap();
        loadHist();
        if (_timer) clearInterval(_timer);
        _timer = setInterval(function() {
            if (!$('#power-ma')) { clearInterval(_timer); _timer = null; return; }
            loadSnap();
        }, 5000);
    }

    App.registerPage('power', renderPower);
    App.setCleanup(function() {
        if (_timer) { clearInterval(_timer); _timer = null; }
    });
})();
