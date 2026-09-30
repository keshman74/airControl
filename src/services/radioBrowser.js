// Shared Internet Radio service.
// Kept outside Electron-specific code so the same React layer can later be
// reused from a Capacitor iOS/Android build.

const RADIO_BROWSER_HOSTS = [
  "https://de1.api.radio-browser.info",
  "https://nl1.api.radio-browser.info"
];

let preferredHost = RADIO_BROWSER_HOSTS[0];

async function fetchJson(path, {timeout=8000}={}) {
  const ordered = [preferredHost, ...RADIO_BROWSER_HOSTS.filter(h => h !== preferredHost)];
  let lastError = null;

  for (const host of ordered) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeout);
    try {
      const response = await fetch(`${host}${path}`, {
        method: "GET",
        headers: {"Accept":"application/json"},
        signal: controller.signal
      });
      if (!response.ok) throw new Error(`Radio Browser HTTP ${response.status}`);
      const data = await response.json();
      preferredHost = host;
      return data;
    } catch (error) {
      lastError = error;
    } finally {
      clearTimeout(timer);
    }
  }

  throw lastError || new Error("Radio Browser is unavailable");
}

function normalizeStation(s={}) {
  return {
    id: String(s.stationuuid || ""),
    name: String(s.name || "Unnamed station").trim(),
    url: String(s.url_resolved || s.url || "").trim(),
    originalUrl: String(s.url || "").trim(),
    favicon: String(s.favicon || "").trim(),
    homepage: String(s.homepage || "").trim(),
    country: String(s.country || "").trim(),
    countryCode: String(s.countrycode || "").trim(),
    language: String(s.language || "").trim(),
    tags: String(s.tags || "").trim(),
    codec: String(s.codec || "").trim(),
    bitrate: Number(s.bitrate) || 0,
    hls: Number(s.hls) === 1,
    votes: Number(s.votes) || 0,
    clicks: Number(s.clickcount) || 0,
    lastCheckOk: Number(s.lastcheckok) === 1,
    lastCheckTime: String(s.lastchecktime_iso8601 || s.lastchecktime || "").trim(),
    sslError: Number(s.ssl_error) === 1
  };
}

function uniqueStations(list=[]) {
  const seen = new Set();
  return list.map(normalizeStation).filter(station => {
    const key = station.id || station.url;
    if (!key || !station.url || seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function stationSearchPath(paramsObj={}) {
  const params = new URLSearchParams();
  for (const [key,value] of Object.entries(paramsObj)) {
    if (value === undefined || value === null || value === "") continue;
    params.set(key, String(value));
  }
  return `/json/stations/search?${params.toString()}`;
}

export async function topRadioStations(limit=36, offset=0) {
  const data = await fetchJson(stationSearchPath({
    hidebroken:"true", order:"clickcount", reverse:"true",
    limit:Math.max(1,Math.min(100,limit)), offset:Math.max(0,offset)
  }));
  return uniqueStations(Array.isArray(data) ? data : []);
}

export async function searchRadioStations({name="", country="", tag="", language="", limit=40, offset=0}={}) {
  const data = await fetchJson(stationSearchPath({
    name:name.trim(), country:country.trim(), tag:tag.trim(), language:language.trim(),
    hidebroken:"true", order:"clickcount", reverse:"true",
    limit:Math.max(1,Math.min(100,limit)), offset:Math.max(0,offset)
  }));
  return uniqueStations(Array.isArray(data) ? data : []);
}

// Radio Browser can contain several records for the same station.  These may
// point at different CDN/origin URLs.  When a CS-8 rejects one stream we can
// try the other records before telling the user the station is unavailable.
export async function findRadioAlternatives(station, limit=16) {
  const name = String(station?.name || "").trim();
  if (!name) return [];
  const data = await fetchJson(stationSearchPath({
    name,
    nameExact:"true",
    countrycode:String(station?.countryCode || "").trim(),
    hidebroken:"true",
    order:"clickcount",
    reverse:"true",
    limit:Math.max(1,Math.min(50,limit))
  }));
  return uniqueStations(Array.isArray(data) ? data : []);
}

export async function countRadioClick(stationId) {
  if (!stationId) return null;
  try {
    return await fetchJson(`/json/url/${encodeURIComponent(stationId)}`, {timeout:5000});
  } catch {
    // Playback must not fail just because the popularity counter is unavailable.
    return null;
  }
}
