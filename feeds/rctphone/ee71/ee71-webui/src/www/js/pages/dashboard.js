;(function() {
    'use strict';
    var $ = App.$, icon = App.icon, escHtml = App.escHtml, actionAttr = App.actionAttr, t = App.t;
    var formatBytes = App.formatBytes, formatSpeed = App.formatSpeed, formatSpeedPair = App.formatSpeedPair, formatUptime = App.formatUptime;

    var _dashTimer = null;
    var _miniChart = null;
    var _sigChart = null;
    var _speedHistory = { t: [], dl: [], ul: [] };

    function renderDashboard(container) {
        // Battery icon removed — just show percentage + charging indicator

        container.innerHTML =
            '<div class="cards-grid">' +
                '<div class="card" id="dash-connection">' +
                    '<h3>' + icon('ic-mobile') + ' ' + escHtml(t('dash.connection')) + ' <span class="status-dot" id="d-conn-dot"></span></h3>' +
                    '<div class="stat-row"><span class="label">' + escHtml(t('dash.operator')) + '</span><span class="value" id="d-operator">\u2014</span></div>' +
                    '<div class="stat-row"><span class="label">' + escHtml(t('dash.technology')) + '</span><span class="value" id="d-tech">\u2014</span></div>' +
                    '<div class="stat-row"><span class="label">' + escHtml(t('dash.signal')) + ' (RSRP)</span><span class="value" id="d-rsrp">\u2014</span></div>' +
                    '<div class="stat-row"><span class="label">' + escHtml(t('dash.band')) + '</span><span class="value" id="d-band">\u2014</span></div>' +
                    '<div class="stat-row" style="border-bottom:none;padding-bottom:2px"><span class="label">Public IP Address</span></div>' +
                    '<div class="stat-row"><span class="label">IPv4</span><span class="value text-mono" id="d-ip">\u2014</span></div>' +
                    '<div class="stat-row" id="d-ip6-row" style="display:none"><span class="label">IPv6</span><span class="value text-mono" id="d-ip6" style="font-size:0.65rem">\u2014</span></div>' +
                '</div>' +
                '<div class="card" id="dash-ca">' +
                    '<h3>' + icon('ic-globe') + ' ' + escHtml(t('dash.ca.title')) + '</h3>' +
                    '<div id="d-ca-body"><span class="text-muted">\u2014</span></div>' +
                '</div>' +
                '<div class="card" id="dash-signal">' +
                    '<h3>' + icon('ic-diag') + ' ' + escHtml(t('dash.sig-history')) + '</h3>' +
                    '<div class="chart-container" id="d-sig-chart" style="min-height:110px"></div>' +
                '</div>' +
                '<div class="card" id="dash-speed">' +
                    '<h3>' + icon('ic-traffic') + ' Speed</h3>' +
                    '<div class="speed-pair">' +
                        '<div class="speed-display">' +
                            '<div class="speed-label">Download</div>' +
                            '<div class="speed-value" id="d-dl-speed">\u2014</div>' +
                            '<div class="speed-unit" id="d-dl-unit"></div>' +
                        '</div>' +
                        '<div class="speed-display">' +
                            '<div class="speed-label">Upload</div>' +
                            '<div class="speed-value" id="d-ul-speed">\u2014</div>' +
                            '<div class="speed-unit" id="d-ul-unit"></div>' +
                        '</div>' +
                    '</div>' +
                    '<div class="chart-container" id="d-speed-chart" style="min-height:120px"></div>' +
                '</div>' +
                '<div class="card" id="dash-devices">' +
                    '<h3>' + icon('ic-clients') + ' ' + escHtml(t('dash.clients')) + '</h3>' +
                    '<div class="stat-row"><span class="label">Connected</span><span class="value" id="d-devcount">\u2014</span></div>' +
                    '<div id="d-devlist" class="mt-1 text-small"></div>' +
                '</div>' +
                '<div class="card" id="dash-usage">' +
                    '<h3>' + icon('ic-traffic') + ' ' + escHtml(t('dash.traffic')) + '</h3>' +
                    '<div class="stat-row">' +
                        '<span class="label">Total</span><span class="value" id="d-usage-total">\u2014</span>' +
                    '</div>' +
                    '<div class="stat-row">' +
                        '<span class="label">\u2193 Download</span><span class="value" id="d-usage-dl">\u2014</span>' +
                    '</div>' +
                    '<div class="stat-row">' +
                        '<span class="label">\u2191 Upload</span><span class="value" id="d-usage-ul">\u2014</span>' +
                    '</div>' +
                '</div>' +
                '<div class="card" id="dash-system">' +
                    '<h3>' + icon('ic-settings') + ' System</h3>' +
                    '<div class="stat-row"><span class="label">' + escHtml(t('dash.uptime')) + '</span><span class="value" id="d-uptime">\u2014</span></div>' +
                    '<div class="stat-row">' +
                        '<span class="label">Battery</span>' +
                        '<span class="value" id="d-battery">\u2014</span>' +
                    '</div>' +
                    '<div class="stat-row">' +
                        '<span class="label">Load Avg</span><span class="value" id="d-cpu">\u2014</span>' +
                        '<div class="progress-thin green" id="d-cpu-bar"><div class="fill" style="width:0%"></div></div>' +
                    '</div>' +
                    '<div class="stat-row">' +
                        '<span class="label">Memory</span><span class="value" id="d-memory">\u2014</span>' +
                        '<div class="progress-thin orange" id="d-mem-bar"><div class="fill" style="width:0%"></div></div>' +
                    '</div>' +
                '</div>' +
                '<div class="card" id="dash-toggles">' +
                    '<h3>' + icon('ic-power') + ' Quick Toggles</h3>' +
                    '<div class="quick-toggles">' +
                        '<div class="switch-row">' +
                            '<span class="switch-row-label">' + icon('ic-wifi') + ' WiFi</span>' +
                            '<label class="switch"><input type="checkbox" id="t-wifi" ' + actionAttr('toggleWifi') + '><span class="slider"></span></label>' +
                        '</div>' +
                        '<div class="switch-row">' +
                            '<span class="switch-row-label">' + icon('ic-globe') + ' Data</span>' +
                            '<label class="switch"><input type="checkbox" id="t-data" ' + actionAttr('toggleData') + '><span class="slider"></span></label>' +
                        '</div>' +
                    '</div>' +
                '</div>' +
            '</div>';

        refreshDashboard();
        _updateSignalChart();
        _dashTimer = setInterval(function() {
            refreshDashboard();
            _updateSignalChart();
        }, 5000);

        App.setCleanup(function() {
            if (_dashTimer) { clearInterval(_dashTimer); _dashTimer = null; }
            if (_miniChart) { _miniChart.destroy(); _miniChart = null; }
            if (_sigChart) { _sigChart.destroy(); _sigChart = null; }
            _speedHistory = { t: [], dl: [], ul: [] };
        });
    }

    function refreshDashboard() {
        Promise.all([
            API.webapi('GetNetworkInfo').catch(function() { return null; }),
            API.webapi('GetConnectionState').catch(function() { return null; }),
            API.webapi('GetBatteryState').catch(function() { return null; }),
            API.cgiGet('clients.cgi', { action: 'list' }).catch(function() { return null; }),
            API.webapi('GetUsageRecord').catch(function() { return null; }),
            API.cgiGet('traffic.cgi', { action: 'status' }).catch(function() { return null; }),
            API.cgiGet('system.cgi', { action: 'cpu' }).catch(function() { return null; }),
        ]).then(function(results) {
            var netInfo = results[0], connSt = results[1], batSt = results[2];
            var devList = results[3], usage = results[4], trafficData = results[5], sysInfo = results[6];

            var el = function(id) { return document.getElementById(id); };

            // Connection card
            if (netInfo) {
                var opName = netInfo.NetworkName || netInfo.Domestic || '';
                if (el('d-operator')) el('d-operator').textContent = opName || '\u2014';
                if (el('d-tech')) el('d-tech').textContent = App.techLabel(netInfo.NetworkType) || '\u2014';
                if (el('d-rsrp')) {
                    var rsrp = netInfo.RSRP;
                    var v = parseInt(rsrp, 10);
                    if (isNaN(v) || v >= -1 || v === 0) {
                        el('d-rsrp').textContent = '\u2014';
                    } else {
                        el('d-rsrp').textContent = rsrp + ' dBm';
                        el('d-rsrp').className = 'value ' + (
                            v >= -80 ? 'text-success' :
                            v >= -100 ? 'text-warn' : 'text-danger'
                        );
                    }
                }
                // Band — use CA data if available, fallback to GetNetworkInfo
                _updateCaCard(netInfo);

                // Connection status dot
                var dot = el('d-conn-dot');
                if (dot) {
                    var hasConn = opName && opName !== 'N/A' && opName !== '\u2014';
                    dot.className = 'status-dot ' + (hasConn ? 'green' : 'red');
                }
            }

            if (connSt) {
                var elIp = el('d-ip');
                if (elIp) elIp.textContent = connSt.IPv4Adrress || connSt.IPAddress || '\u2014';
                var ipv6 = connSt.IPv6Adrress || '';
                var elIp6 = el('d-ip6');
                var elIp6Row = el('d-ip6-row');
                if (elIp6) elIp6.textContent = ipv6 || '\u2014';
                if (elIp6Row) elIp6Row.style.display = ipv6 ? '' : 'none';
            }

            // Speed (from traffic_stats) — same unit for DL/UL
            if (trafficData && trafficData.wan) {
                var sp = formatSpeedPair(trafficData.wan.rx_speed, trafficData.wan.tx_speed);
                if (el('d-dl-speed')) el('d-dl-speed').textContent = sp.dl.value;
                if (el('d-dl-unit')) el('d-dl-unit').textContent = sp.unit;
                if (el('d-ul-speed')) el('d-ul-speed').textContent = sp.ul.value;
                if (el('d-ul-unit')) el('d-ul-unit').textContent = sp.unit;
            }

            // Devices (from clients.cgi)
            if (devList) {
                var devices = Array.isArray(devList) ? devList : (devList.ConnectedList || []);
                if (el('d-devcount')) el('d-devcount').textContent = devices.length;

                var elList = el('d-devlist');
                if (elList) {
                    if (devices.length === 0) {
                        elList.textContent = 'No devices connected';
                    } else {
                        elList.innerHTML = devices.slice(0, 8).map(function(d) {
                            var name = (d.name || d.DeviceName || d.HostName || '').toLowerCase();
                            var isPhone = /iphone|ipad|android|galaxy|pixel|xiaomi|redmi|huawei|oneplus|oppo|vivo|samsung|poco|realme|watch/.test(name);
                            var devIcon = isPhone ? 'ic-mobile' : 'ic-computer';
                            var conn = d.connection || '';
                            var connIcon = conn === 'usb' ? 'ic-usb' : 'ic-wifi';
                            var signal = d.rssi != null ? ' ' + App.escHtml(d.rssi) + ' dBm' : '';
                            return '<div class="device-row">' +
                                icon(devIcon) +
                                '<span class="device-name">' + escHtml(d.name || d.DeviceName || d.HostName || d.ip || d.mac || '?') + '</span>' +
                                '<span class="device-ip">' + escHtml(d.ip || d.IpAddress || '') + signal + '</span>' +
                                '<span class="device-signal">' + icon(connIcon) + '</span>' +
                                '</div>';
                        }).join('');
                        if (devices.length > 8) {
                            elList.innerHTML += '<div class="text-muted text-center mt-1">+' + (devices.length - 8) + ' more</div>';
                        }
                    }
                }
            }

            // Usage (from modem counters)
            if (usage) {
                var ul = parseInt(usage.HCurrUseUL, 10) || 0;
                var dlBytes = parseInt(usage.HCurrUseDL, 10) || 0;
                if (el('d-usage-total')) el('d-usage-total').textContent = formatBytes(ul + dlBytes);
                if (el('d-usage-dl')) el('d-usage-dl').textContent = formatBytes(dlBytes);
                if (el('d-usage-ul')) el('d-usage-ul').textContent = formatBytes(ul);
            }

            // Battery
            if (batSt) {
                var elBat = el('d-battery');
                if (elBat) {
                    var charging = batSt.chg_state === 1 || batSt.BatteryState === 1 || batSt.BatteryState === '1';
                    var batLvl = batSt.BatteryLevel != null ? batSt.BatteryLevel : '?';
                    elBat.innerHTML = batLvl + '%' + (charging ? ' \u26A1' : '');
                }
            }

            // System info (CPU)
            if (sysInfo) {
                if (el('d-cpu') && sysInfo.load1) {
                    el('d-cpu').textContent = sysInfo.load1;
                    var cpuPct = Math.min(Math.round(parseFloat(sysInfo.load1) * 100), 100);
                    var cpuBar = el('d-cpu-bar');
                    if (cpuBar) {
                        cpuBar.querySelector('.fill').style.width = cpuPct + '%';
                    }
                }
            }

            // Memory
            API.cgiGet('system.cgi', { action: 'memory' }).then(function(mem) {
                if (mem && mem.MemTotal && el('d-memory')) {
                    var used = mem.MemTotal - (mem.MemFree || 0) - (mem.Buffers || 0) - (mem.Cached || 0);
                    var memPct = Math.round(used / mem.MemTotal * 100);
                    el('d-memory').textContent = memPct + '%';
                    var memBar = el('d-mem-bar');
                    if (memBar) memBar.querySelector('.fill').style.width = memPct + '%';
                }
            }).catch(function() {});

            // Uptime
            API.cgiGet('system.cgi', { action: 'uptime' }).then(function(u) {
                if (u && u.seconds != null && el('d-uptime')) el('d-uptime').textContent = formatUptime(u.seconds);
            }).catch(function() {});

            // Toggle states
            API.webapi('GetWlanState').then(function(wlanSt) {
                var tWifi = el('t-wifi');
                if (tWifi && wlanSt) tWifi.checked = (wlanSt.WlanState === 1 || wlanSt.WlanState === '1');
            }).catch(function() {});

            var tData = el('t-data');
            if (tData && connSt) {
                tData.checked = (connSt.ConnectionStatus === 2 || connSt.ConnectionStatus === '2');
            }

            // Mini speed chart
            _updateMiniChart(trafficData);
        }).catch(function() {
            // Dashboard refresh failed
        });
    }

    // CA-карточка: краткая строка в сводке + таблица компонентных несущих.
    // Данные — из кэша signal_ca_poller (мгновенно); при недоступности —
    // fallback на GetNetworkInfo.Band.
    function _updateCaCard(netInfo) {
        API.cgiGet('signal.cgi', { action: 'ca' }).then(function(ca) {
            var bandEl = document.getElementById('d-band');
            var bodyEl = document.getElementById('d-ca-body');
            var cells = (ca && ca.cells) || [];
            var live = cells.filter(function(c) { return c.band > 0; });

            if (live.length > 1) {
                var bands = live.map(function(c) { return 'B' + c.band; });
                if (bandEl) bandEl.textContent = bands.join('+');
                if (bodyEl) {
                    var rows = live.map(function(c) {
                        var cls = c.rsrp != null ? (
                            c.rsrp >= -80 ? 'text-success' :
                            c.rsrp >= -100 ? 'text-warn' : 'text-danger') : '';
                        return '<tr>' +
                            '<td style="padding:.2rem .25rem .2rem 0;white-space:nowrap;overflow:hidden">' + escHtml(c.type.toUpperCase()) + '</td>' +
                            '<td style="padding:.2rem .25rem;white-space:nowrap;overflow:hidden">B' + escHtml(c.band) + '</td>' +
                            '<td style="padding:.2rem .25rem;white-space:nowrap;overflow:hidden">' + escHtml(c.earfcn) + '</td>' +
                            '<td style="padding:.2rem .25rem;white-space:nowrap;overflow:hidden">' + (c.pci != null ? escHtml(c.pci) : '\u2014') + '</td>' +
                            '<td class="' + cls + '" style="padding:.2rem 0 .2rem .25rem;white-space:nowrap;overflow:hidden">' + (c.rsrp != null ? escHtml(c.rsrp) : '\u2014') + '</td>' +
                            '</tr>';
                    }).join('');
                    var note = live.length > 2 ? '<div class="text-muted" style="font-size:.65rem;margin-top:.3rem">CA ≤2CC — строки сверх 2 это соседние ячейки, не несущие</div>' : '';
                    bodyEl.innerHTML =
                        '<table class="ca-table" style="width:100%;font-size:.72rem;border-collapse:collapse;table-layout:fixed">' +
                        '<thead><tr style="text-align:left;opacity:.7">' +
                        '<th style="padding:.15rem .25rem .15rem 0;white-space:nowrap;overflow:hidden">' + escHtml(t('dash.ca.cell')) + '</th>' +
                        '<th style="padding:.15rem .25rem;white-space:nowrap;overflow:hidden">' + escHtml(t('dash.ca.band')) + '</th>' +
                        '<th style="padding:.15rem .25rem;white-space:nowrap;overflow:hidden">' + escHtml(t('dash.ca.earfcn')) + '</th>' +
                        '<th style="padding:.15rem .25rem;white-space:nowrap;overflow:hidden">' + escHtml(t('dash.ca.pci')) + '</th>' +
                        '<th style="padding:.15rem 0 .15rem .25rem;white-space:nowrap;overflow:hidden">' + escHtml(t('dash.ca.rsrp')) + ', dBm</th>' +
                        '</tr></thead><tbody>' + rows + '</tbody></table>' + note;
                }
            } else if (live.length === 1) {
                if (bandEl) bandEl.textContent = 'LTE B' + live[0].band;
                if (bodyEl) bodyEl.innerHTML = '<span class="text-muted">' + escHtml(t('dash.ca.none')) + '</span>';
            } else {
                if (bandEl) bandEl.textContent = App.formatBand(netInfo.Band) || '\u2014';
                if (bodyEl) bodyEl.innerHTML = '<span class="text-muted">' + escHtml(t('dash.ca.none')) + '</span>';
            }
        }).catch(function() {
            var bandEl = document.getElementById('d-band');
            if (bandEl) bandEl.textContent = App.formatBand(netInfo.Band) || '\u2014';
        });
    }

    // История RSRP/SINR из /tmp/signal_history.json (traffic_stats, 64 точки)
    function _updateSignalChart() {
        API.cgiGet('signal.cgi', { action: 'history' }).then(function(hist) {
            var chartEl = document.getElementById('d-sig-chart');
            if (!chartEl || !Array.isArray(hist) || hist.length < 2) return;

            var xs = hist.map(function(p) { return p.t; });
            var rsrp = hist.map(function(p) { return p.rsrp; });
            var sinr = hist.map(function(p) { return p.sinr; });

            var data = [xs, rsrp, sinr];
            if (_sigChart) {
                _sigChart.setData(data);
            } else {
                _sigChart = new uPlot({
                    width: chartEl.clientWidth || 300,
                    height: 110,
                    cursor: { show: false },
                    legend: { show: false },
                    scales: { x: { time: false } },
                    axes: [{ show: false }, { show: false }],
                    series: [
                        {},
                        { stroke: '#0077cc', fill: 'rgba(0,119,204,0.12)', width: 1.5 },
                        { stroke: '#e6a23c', width: 1.5 },
                    ],
                }, data, chartEl);
            }
        }).catch(function() {});
    }

    function _toggleWifi() {
        API.webapi('GetWlanState').then(function(st) {
            var isOn = st && (st.WlanState === 1 || st.WlanState === '1');
            return API.webapi(isOn ? 'SetWlanOff' : 'SetWlanOn');
        }).then(function() {
            setTimeout(refreshDashboard, 1000);
        }).catch(function() {});
    }

    function _toggleData() {
        API.webapi('GetConnectionState').then(function(st) {
            var connected = st && (st.ConnectionStatus === 2 || st.ConnectionStatus === '2');
            return API.webapi(connected ? 'DisConnect' : 'Connect');
        }).then(function() {
            setTimeout(refreshDashboard, 2000);
        }).catch(function() {});
    }

    function _updateMiniChart(trafficData) {
        if (!trafficData || !trafficData.wan) return;
        var chartEl = document.getElementById('d-speed-chart');
        if (!chartEl) return;

        var now = Math.floor(Date.now() / 1000);
        _speedHistory.t.push(now);
        _speedHistory.dl.push((trafficData.wan.rx_speed || 0) * 8 / 1000000);
        _speedHistory.ul.push((trafficData.wan.tx_speed || 0) * 8 / 1000000);
        var MAX = 36;
        if (_speedHistory.t.length > MAX) {
            _speedHistory.t = _speedHistory.t.slice(-MAX);
            _speedHistory.dl = _speedHistory.dl.slice(-MAX);
            _speedHistory.ul = _speedHistory.ul.slice(-MAX);
        }
        if (_speedHistory.t.length < 2) return;

        var data = [_speedHistory.t, _speedHistory.dl, _speedHistory.ul];
        if (_miniChart) {
            _miniChart.setData(data);
        } else {
            _miniChart = new uPlot({
                width: chartEl.clientWidth || 300,
                height: 120,
                cursor: { show: false },
                legend: { show: false },
                scales: { x: { time: false }, y: { auto: true, range: [0, null] } },
                axes: [{ show: false }, { show: false }],
                series: [
                    {},
                    { stroke: '#0077cc', fill: 'rgba(0,119,204,0.15)', width: 1.5 },
                    { stroke: '#2e7d32', fill: 'rgba(46,125,50,0.15)', width: 1.5 },
                ],
            }, data, chartEl);
        }
    }

    App.registerPage('dashboard', renderDashboard);
    App.refreshDashboard = refreshDashboard;
    App._toggleWifi = _toggleWifi;
    App._toggleData = _toggleData;
})();
