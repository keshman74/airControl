import { CapacitorHttp } from '@capacitor/core';

const SERVICE = 'urn:schemas-wiimu-com:service:PlayQueue:1';
const SOAP = 'http://schemas.xmlsoap.org/soap/envelope/';
export const queues = ['TotalQueue', 'CurrentQueue', 'USBDiskQueue'];

export function privateHost(input) {
  const parts = input.trim().split('.');
  if (parts.length !== 4 || parts.some(part => !/^(0|[1-9]\d{0,2})$/.test(part) || Number(part) > 255)) {
    throw new Error('Введите локальный IPv4-адрес устройства.');
  }
  const [a, b] = parts.map(Number);
  if (!(a === 10 || a === 172 && b >= 16 && b <= 31 || a === 192 && b === 168)) {
    throw new Error('Адрес должен быть в частной сети.');
  }
  return parts.join('.');
}

function xml(text) {
  if (typeof text !== 'string') throw new Error('Устройство вернуло ответ в неожиданном формате.');
  const doc = new DOMParser().parseFromString(text, 'application/xml');
  if (!doc.documentElement || doc.getElementsByTagNameNS('*', 'parsererror').length) {
    throw new Error('Устройство вернуло некорректный XML.');
  }
  return doc.documentElement;
}

const child = (node, name) => Array.from(node?.children ?? []).find(item => item.localName === name);
const field = (node, name) => child(node, name)?.textContent.trim() ?? '';
const descendants = (node, name) => Array.from(node.getElementsByTagNameNS('*', name));

function textValue(value) {
  return value.toLowerCase() === 'unknown' ? '' : value;
}

function artworkURL(value) {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && !url.username && !url.password ? url.href : '';
  } catch {
    return '';
  }
}

function pathTitle(value) {
  if (!value.startsWith('/media/')) return '';
  const file = value.split('/').at(-1);
  try {
    return decodeURIComponent(file);
  } catch {
    return file;
  }
}

function trackFrom(node) {
  const url = field(node, 'URL');
  const metadata = field(node, 'Metadata');
  let item;
  if (metadata) {
    try {
      item = descendants(xml(metadata), 'item')[0];
    } catch {
      // A31 can return malformed DIDL for individual USB tracks.
    }
  }
  return {
    title: textValue(field(item, 'title')) || pathTitle(url) || 'Без названия',
    artist: textValue(field(item, 'artist')),
    album: textValue(field(item, 'album')),
    artwork: artworkURL(field(item, 'albumArtURI')),
  };
}

export function parseQueueContext(raw) {
  const root = xml(raw);
  if (root.localName === 'PlayQueue') {
    return {
      kind: 'catalog',
      active: field(child(root, 'CurrentPlayList'), 'Name'),
      entries: Array.from(child(root, 'PlayListInfo')?.children ?? [])
        .map(item => field(item, 'Name')).filter(Boolean),
    };
  }
  if (root.localName !== 'PlayList') throw new Error('Неизвестный формат QueueContext.');
  const info = child(root, 'ListInfo');
  const tracks = Array.from(child(root, 'Tracks')?.children ?? []).map(trackFrom);
  const index = field(info, 'LastPlayIndex');
  const source = field(info, 'SourceName');
  const position = /^[1-9]\d*$/.test(index) ? Number(index) : 0;
  // The one-based mapping is verified for USB and Qobuz on the tested A31.
  const activeIndex = ['USBDiskQueue', 'Qobuz'].includes(source) && position <= tracks.length && position > 0
    ? position - 1 : null;
  return { kind: 'playlist', name: field(root, 'ListName'), source, tracks, activeIndex };
}

function localURL(address, host, base) {
  const url = new URL(address, base);
  if (url.protocol !== 'http:' || url.hostname !== host || url.username || url.password) {
    throw new Error('Устройство указало внешний адрес UPnP.');
  }
  return url.href;
}

export class LinkplayClient {
  constructor(host, http = CapacitorHttp) {
    this.host = privateHost(host);
    this.http = http;
  }

  async request(url, options = {}) {
    const response = await this.http.request({
      method: 'GET', responseType: 'text', connectTimeout: 3000, readTimeout: 6000,
      disableRedirects: true, ...options, url: localURL(url, this.host),
    });
    return response;
  }

  async playerInfo(command) {
    const { status, data } = await this.request(`http://${this.host}/httpapi.asp?command=${command}`);
    if (status !== 200) throw new Error(`HTTPAPI вернул HTTP ${status}.`);
    const parsed = typeof data === 'string' ? JSON.parse(data) : data;
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      throw new Error('Не удалось прочитать состояние устройства.');
    }
    return parsed;
  }

  async connect() {
    const identity = await this.playerInfo('getStatusEx');
    if (!identity.uuid || !identity.firmware) throw new Error('Устройство не вернуло UUID и прошивку.');
    this.identity = identity;
    return identity;
  }

  async discoverQueue() {
    if (!this.identity) throw new Error('Сначала подключитесь к устройству.');
    for (const port of [59152, 49152, 80]) {
      try {
        const address = `http://${this.host}:${port}/description.xml`;
        const description = await this.request(address);
        if (description.status !== 200) continue;
        const root = xml(description.data);
        const service = descendants(root, 'service').find(node => field(node, 'serviceType') === SERVICE);
        const scpdPath = field(service, 'SCPDURL');
        const controlPath = field(service, 'controlURL');
        if (!scpdPath || !controlPath) continue;
        const base = localURL(field(root, 'URLBase') || address, this.host, address);
        const control = localURL(controlPath, this.host, base);
        const scpd = await this.request(localURL(scpdPath, this.host, base));
        if (scpd.status !== 200) continue;
        const action = descendants(xml(scpd.data), 'action').find(node => field(node, 'name') === 'BrowseQueue');
        const args = Array.from(child(action, 'argumentList')?.children ?? []);
        if (args.some(node => field(node, 'name') === 'QueueName' && field(node, 'direction') === 'in') &&
            args.some(node => field(node, 'name') === 'QueueContext' && field(node, 'direction') === 'out')) {
          this.control = control;
          return;
        }
      } catch {
        // The known UPnP ports are candidates. Try the next advertised description.
      }
    }
    throw new Error('Устройство не объявило совместимую операцию BrowseQueue.');
  }

  async browse(queue) {
    if (!queues.includes(queue)) throw new Error('Неизвестная очередь.');
    if (!this.control) await this.discoverQueue();
    const body = `<s:Envelope xmlns:s="${SOAP}"><s:Body><u:BrowseQueue xmlns:u="${SERVICE}"><QueueName>${queue}</QueueName></u:BrowseQueue></s:Body></s:Envelope>`;
    const response = await this.request(this.control, {
      method: 'POST', data: body,
      headers: { 'Content-Type': 'text/xml; charset="utf-8"', SOAPAction: `"${SERVICE}#BrowseQueue"` },
    });
    const envelope = xml(response.data);
    const fault = descendants(envelope, 'Fault')[0];
    if (fault) {
      const error = descendants(fault, 'errorCode')[0]?.textContent;
      throw new Error(error ? `Устройство отклонило запрос очереди (UPnP ${error}).` : 'Устройство отклонило запрос очереди.');
    }
    const soapBody = child(envelope, 'Body');
    const reply = child(soapBody, 'BrowseQueueResponse');
    const context = child(reply, 'QueueContext');
    if (response.status !== 200 || envelope.namespaceURI !== SOAP || soapBody?.namespaceURI !== SOAP ||
        reply?.namespaceURI !== SERVICE || !context) {
      throw new Error(`Неожиданный ответ BrowseQueue (HTTP ${response.status}).`);
    }
    const raw = context.firstElementChild ? new XMLSerializer().serializeToString(context.firstElementChild) : context.textContent;
    return raw.trim() ? parseQueueContext(raw) : { kind: 'playlist', tracks: [], activeIndex: null };
  }
}
