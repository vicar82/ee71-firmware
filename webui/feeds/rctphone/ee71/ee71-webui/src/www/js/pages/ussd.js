;(function() {
    'use strict';
    var $ = App.$, escHtml = App.escHtml, actionAttr = App.actionAttr, t = App.t;

    var _ussdBusy = false;

    function renderUssd(container) {
        container.innerHTML =
            '<div class="card">' +
                '<h3>' + escHtml(t('ussd.title')) + '</h3>' +
                '<p class="page-hint">' + escHtml(t('ussd.hint')) + '</p>' +
                '<div class="ussd-quick" style="margin-bottom:1rem;display:flex;gap:.5rem;flex-wrap:wrap">' +
                    '<button class="btn-outline" data-action="ussdQuick" data-args="[&quot;*102#&quot;]">' + escHtml(t('ussd.balance')) + ' *102#</button>' +
                    '<button class="btn-outline" data-action="ussdQuick" data-args="[&quot;*141#&quot;]">' + escHtml(t('ussd.traffic')) + ' *141#</button>' +
                    '<button class="btn-outline" data-action="ussdQuick" data-args="[&quot;*110*9#&quot;]">' + escHtml(t('ussd.number')) + '</button>' +
                '</div>' +
                '<div class="form-group">' +
                    '<label for="ussd-code">' + escHtml(t('ussd.input')) + '</label>' +
                    '<input type="text" id="ussd-code" maxlength="20" placeholder="*102#" autocomplete="off">' +
                '</div>' +
                '<button class="btn-primary" id="ussd-send" data-action="ussdSend">' + escHtml(t('ussd.send')) + '</button>' +
                '<div id="ussd-result" style="margin-top:1rem"></div>' +
            '</div>';

        var input = $('#ussd-code');
        if (input) input.addEventListener('keydown', function(e) {
            if (e.key === 'Enter') { e.preventDefault(); App._ussdSend(); }
        });
    }

    function _setBusy(busy) {
        _ussdBusy = busy;
        var btn = $('#ussd-send');
        if (btn) { btn.disabled = busy; btn.textContent = busy ? t('common.loading') : t('ussd.send'); }
    }

    function _showResult(html, isError) {
        var box = $('#ussd-result');
        if (!box) return;
        box.innerHTML = '<div class="card" style="background:var(--bg-surface-secondary)">' +
            '<div class="stat-row"><span class="label">' + escHtml(t('ussd.response')) + '</span></div>' +
            '<pre style="white-space:pre-wrap;margin:.25rem 0 0;' +
            (isError ? 'color:var(--color-danger,#d9534f)' : '') + '">' + html + '</pre></div>';
    }

    function _send(code) {
        code = (code || '').trim();
        if (!code) return;
        if (_ussdBusy) return;
        if (!/^[\d*#]{3,20}$/.test(code)) {
            _showResult(escHtml(t('common.error')) + ': ' + escHtml(code), true);
            return;
        }
        _setBusy(true);
        _showResult(escHtml(t('common.loading')), false);
        API.cgiPost('ussd.cgi', { action: 'send', cmd: code }).then(function(r) {
            if (r.error) {
                _showResult(escHtml(r.error), true);
            } else {
                _showResult(escHtml(r.response || '(empty)'), false);
            }
        }).catch(function(e) {
            _showResult(escHtml(App.errorText(e)), true);
        }).then(function() { _setBusy(false); });
    }

    App.registerPage('ussd', renderUssd);
    App._ussdSend = function() { _send(($('#ussd-code') || {}).value); };
    App._ussdQuick = function(code) {
        var input = $('#ussd-code');
        if (input) input.value = code;
        _send(code);
    };
})();
