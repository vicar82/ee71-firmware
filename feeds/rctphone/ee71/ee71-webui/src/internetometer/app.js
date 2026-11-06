
var timer = null;
function el(id){ return document.getElementById(id); }
function showErr(m){ el('err').style.display='block'; el('err').textContent=m; }
function start(){
  el('err').style.display='none';
  el('results').style.display='none';
  el('go').disabled = true;
  fetch('/cgi-bin/internetometer.cgi?action=start', {method:'POST', headers:{'X-EE71-Request':'1'}})
    .then(function(r){ return r.json().catch(function(){ return {}; }); })
    .then(function(){ timer = setInterval(poll, 1000); poll(); })
    .catch(function(e){ el('go').disabled=false; showErr('Не удалось запустить: '+e); });
}
function poll(){
  fetch('/cgi-bin/internetometer.cgi?action=poll')
    .then(function(r){ return r.json(); })
    .then(function(d){
      if (d.error) { stop(); showErr(d.error); return; }
      el('status').textContent = d.done ? 'Готово' : ('Измерение: ' + (d.stage||'') + ' ' + (d.progress||0) + '%');
      if (d.download_mbps) { el('results').style.display='block'; el('dl').textContent = Number(d.download_mbps).toFixed(1); }
      if (d.upload_mbps)   el('ul').textContent = Number(d.upload_mbps).toFixed(1);
      if (d.ping_ms)       el('pg').textContent = Number(d.ping_ms).toFixed(0);
      if (d.ip)            el('ip').textContent = d.ip;
      if (d.server)        el('srv').textContent = d.server;
      if (d.region)        el('meta').textContent = d.region;
      if (d.done) stop(true);
    })
    .catch(function(){ /* промежуточный сбой — просто опрашиваем дальше */ });
}
function stop(done){
  clearInterval(timer); timer=null;
  el('go').disabled=false;
  if (done) el('status').textContent='Готово';
}
el('go').addEventListener('click', start);
