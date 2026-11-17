/* OpenThinRDP website counter (see privacy.html, "This website").
   No cookies, nothing stored in the browser, a random id for each page view,
   no IP address (the PostHog EU project discards it) and no place from it. */
(function () {
  if (location.hostname !== 'openthinrdp.github.io') return;
  var KEY = 'phc_BEG5o8qxzJmJpuRfKbA9EZ6TvTy35NeDUFGWfbQx2cFx';
  var EP = 'https://eu.i.posthog.com/i/v0/e/';

  function rid() {
    try { return crypto.randomUUID(); } catch (e) { return Date.now().toString(36) + Math.random().toString(36).slice(2); }
  }
  var ref = (document.referrer || '').split(/[?#]/)[0], refHost = '';
  try { refHost = ref ? new URL(ref).hostname : ''; } catch (e) {}
  if (refHost && refHost === location.hostname) refHost = 'internal';
  var from = '';
  try { from = (new URLSearchParams(location.search).get('from') || '').slice(0, 40); } catch (e) {}

  function send(event, extra) {
    var p = {
      $lib: 'openthinrdp-site', $process_person_profile: false, $geoip_disable: true,
      $current_url: location.origin + location.pathname, $host: location.hostname, $pathname: location.pathname,
      $referrer: ref || '$direct', $referring_domain: refHost || '$direct',
      $screen_width: screen.width, $browser_language: navigator.language || ''
    };
    if (from) p.from = from;
    for (var k in extra) p[k] = extra[k];
    var body = JSON.stringify({ api_key: KEY, event: event, distinct_id: rid(), properties: p, timestamp: new Date().toISOString() });
    try { fetch(EP, { method: 'POST', body: body, keepalive: true, headers: { 'Content-Type': 'text/plain' } }); } catch (e) {}
  }

  send('$pageview', {});

  document.addEventListener('click', function (e) {
    var a = e.target && e.target.closest ? e.target.closest('a[href]') : null;
    if (!a) return;
    var h = a.href, what = '';
    if (/github\.com\/OpenThinRdp\/openthinrdp-manager\/releases/i.test(h)) what = 'manager';
    else if (/github\.com\/OpenThinRdp\/openthinrdp\/releases|\.iso([?#]|$)/i.test(h)) what = 'iso';
    else if (/^https:\/\/github\.com\/OpenThinRdp\//i.test(h)) what = 'github';
    if (what) send('site_click', { what: what, label: (a.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 60) });
  }, true);
})();
