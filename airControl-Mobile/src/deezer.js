import { CapacitorHttp } from '@capacitor/core';
import { escapeXml } from './linkplay.js';

// Compatibility encoding observed in Audio Pro Legacy's native library. This is obfuscation, not encryption.
export function encodeLegacyDeezerPassword(password) {
  const bytes = [];
  for (let index = 0; index < password.length; index += 1) {
    const unit = password.charCodeAt(index);
    if (unit === 0) bytes.push(0xc0, 0x80);
    else if (unit < 0x80) bytes.push(unit);
    else if (unit < 0x800) bytes.push(0xc0 | unit >> 6, 0x80 | unit & 0x3f);
    else bytes.push(0xe0 | unit >> 12, 0x80 | unit >> 6 & 0x3f, 0x80 | unit & 0x3f);
  }
  let state = 0x1e00;
  return bytes.slice(0, 255).map(byte => {
    const transformed = byte ^ (state >>> 8);
    state = (((state & 0xffff) + transformed) * 0xce6d + 0x58bf) >>> 0;
    return String.fromCharCode(65 + Math.floor(transformed / 26), 65 + transformed % 26);
  }).join('');
}

function toBase64(text) {
  const bytes = new TextEncoder().encode(text);
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

async function md5Hex(text) {
  const bytes = new TextEncoder().encode(text);
  const paddedLength = Math.ceil((bytes.length + 9) / 64) * 64;
  const data = new Uint8Array(paddedLength);
  data.set(bytes);
  data[bytes.length] = 0x80;
  const bitLength = bytes.length * 8;
  const view = new DataView(data.buffer);
  view.setUint32(paddedLength - 8, bitLength >>> 0, true);
  view.setUint32(paddedLength - 4, Math.floor(bitLength / 0x100000000), true);
  const shifts = [7, 12, 17, 22, 5, 9, 14, 20, 4, 11, 16, 23, 6, 10, 15, 21];
  const constants = Array.from({ length: 64 }, (_, index) => Math.floor(Math.abs(Math.sin(index + 1)) * 0x100000000) >>> 0);
  const rotate = (value, count) => (value << count) | (value >>> (32 - count));
  const state = [0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476];
  for (let offset = 0; offset < data.length; offset += 64) {
    const words = Array.from({ length: 16 }, (_, index) => view.getUint32(offset + index * 4, true));
    let [a, b, c, d] = state;
    for (let index = 0; index < 64; index += 1) {
      let f; let g; let shift;
      if (index < 16) { f = (b & c) | (~b & d); g = index; shift = shifts[index % 4]; }
      else if (index < 32) { f = (d & b) | (~d & c); g = (5 * index + 1) % 16; shift = shifts[4 + index % 4]; }
      else if (index < 48) { f = b ^ c ^ d; g = (3 * index + 5) % 16; shift = shifts[8 + index % 4]; }
      else { f = c ^ (b | ~d); g = (7 * index) % 16; shift = shifts[12 + index % 4]; }
      const sum = (a + f + constants[index] + words[g]) >>> 0;
      const nextB = (b + rotate(sum, shift)) >>> 0;
      a = d; d = c; c = b; b = nextB;
    }
    state[0] = (state[0] + a) >>> 0;
    state[1] = (state[1] + b) >>> 0;
    state[2] = (state[2] + c) >>> 0;
    state[3] = (state[3] + d) >>> 0;
  }
  let hex = state.map(word => [0, 8, 16, 24].map(shift => ((word >>> shift) & 0xff).toString(16).padStart(2, '0')).join('')).join('');
  return hex.replace(/^0+/, '') || '0'; // Java BigInteger(1, digest).toString(16)
}

function catalogURL(value, base) {
  let url;
  try { url = new URL(value, base); } catch { throw new Error('Каталог Deezer вернул некорректную ссылку.'); }
  if (url.protocol !== 'https:' || !url.hostname.endsWith('.airable.io') || url.username || url.password || url.port) {
    throw new Error('Ссылка каталога Deezer не относится к безопасному серверу airable.');
  }
  return url;
}

function objectValue(value) {
  if (typeof value === 'string') {
    try { return JSON.parse(value); } catch { throw new Error('Каталог Deezer вернул некорректный JSON.'); }
  }
  return value;
}

function numericTrackId(entry) {
  const candidates = [entry.track_id, entry.id, entry.url, entry.uri];
  for (const candidate of candidates) {
    const match = String(candidate ?? '').match(/(?:^|[,/:])\s*\[?([0-9]{2,})\]?\s*(?:[?#].*)?$/);
    if (match) return match[1];
  }
  return '';
}

function imageURL(entry) {
  const value = entry.images?.[0]?.url || entry.image || entry.cover || '';
  try {
    const url = new URL(value);
    return url.protocol === 'https:' ? url.href : '';
  } catch { return ''; }
}

export class DeezerClient {
  constructor(linkplay, http = CapacitorHttp) {
    this.linkplay = linkplay;
    this.http = http;
    this.startedAt = Math.floor(Date.now() / 1000);
  }

  async userInfo() {
    this.startedAt = Math.floor(Date.now() / 1000);
    const result = await this.linkplay.playQueueAction('GetUserInfo', { AccountSource: 'Deezer' });
    const info = objectValue(result.Result ?? result.UserInfo ?? '{}');
    if (!info || typeof info !== 'object' || Array.isArray(info)) throw new Error('Устройство вернуло неизвестный статус Deezer.');
    return info;
  }

  async login(username, password) {
    if (!username.trim() || !password) throw new Error('Введите логин и пароль Deezer.');
    const payload = {
      AccountSource: 'Deezer', UserName: username.trim(), PassWord: encodeLegacyDeezerPassword(password),
      Code: '', Proxy: '', SavePass: '0', Token: '',
    };
    await this.linkplay.playQueueAction('UserLogin', payload);
    this.loginPassword = password;
    this.startedAt = Math.floor(Date.now() / 1000);
    const info = await this.userInfo();
    if (!this.ready(info)) throw new Error(cleanMessage(info.msg) || 'Устройство не подтвердило вход Deezer.');
    return info;
  }

  ready(info) {
    return Boolean(info && info.msg !== 'not login' && info.msg !== 'action timeout' &&
      info.access_token && info.deezer_secret && info.list_url);
  }

  authHeader(info) {
    const deviceNow = Math.floor(Date.now() / 1000) + Number(info.fw_cur_time || 0) + Number(info.offset_time || 0) - this.startedAt;
    return md5Hex(`${info.access_token}${info.deezer_secret}${deviceNow}`).then(digest =>
      `Basic ${toBase64(`${info.access_token}:${digest}`)}`);
  }

  async page(info, address = info.list_url, query = '') {
    if (!this.ready(info)) throw new Error('Выполните вход в Deezer на устройстве.');
    const url = catalogURL(address, info.list_url);
    if (query) {
      url.searchParams.set('t', 'all');
      url.searchParams.set('q', query);
    }
    const response = await this.http.request({
      method: 'GET', url: url.href, responseType: 'text', connectTimeout: 8000, readTimeout: 15000,
      disableRedirects: true,
      headers: { Accept: 'application/json', Authorization: await this.authHeader(info) },
    });
    if (response.status < 200 || response.status >= 300) {
      if (response.status === 401 || response.status === 403) throw new Error('Сессия Deezer отклонена устройством. Войдите снова.');
      throw new Error(`Каталог Deezer ответил HTTP ${response.status}.`);
    }
    const root = objectValue(response.data);
    if (!root || typeof root !== 'object') throw new Error('Каталог Deezer вернул пустой ответ.');
    return { root, url: url.href };
  }

  entries(root) {
    const content = root.content ?? root;
    return Array.isArray(content.entries) ? content.entries : Array.isArray(root.entries) ? root.entries : [];
  }

  async play(entries, selectedIndex, info, context) {
    const playable = entries.filter(entry => numericTrackId(entry));
    const selectedId = numericTrackId(entries[selectedIndex]);
    const startIndex = Math.max(0, playable.findIndex(entry => numericTrackId(entry) === selectedId));
    if (!playable.length || !selectedId) throw new Error('В записи каталога не найден идентификатор трека Deezer.');
    const tracks = playable.map((entry, index) => {
      const id = numericTrackId(entry);
      const title = entry.title || entry.name || 'Deezer';
      const artist = entry.artist?.title || entry.artist?.name || entry.artist || '';
      const album = entry.album?.title || entry.album?.name || entry.album || '';
      const art = imageURL(entry);
      const metadata = `<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns:song="www.linkplay.com/song/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"><upnp:class>object.item.audioItem.musicTrack</upnp:class><item><song:id>${escapeXml(id)}</song:id><dc:title>${escapeXml(title)}</dc:title><upnp:artist>${escapeXml(artist)}</upnp:artist><upnp:album>${escapeXml(album)}</upnp:album><res protocolInfo="http-get:*:audio/mpeg:*">wiimu_search://${escapeXml(id)}</res>${art ? `<upnp:albumArtURI>${escapeXml(art)}</upnp:albumArtURI>` : ''}</item></DIDL-Lite>`;
      return `<Track${index + 1}><URL>wiimu_search://${escapeXml(id)}</URL><Source>Deezer</Source><Key></Key><Id>${escapeXml(id)}</Id><Metadata>${escapeXml(metadata)}</Metadata></Track${index + 1}>`;
    }).join('');
    const listName = context?.title || context?.name || playable[startIndex].title || 'Deezer';
    const queuePassword = this.loginPassword || info.user_password || '';
    const queue = `<?xml version="1.0" ?><PlayList><ListName>${escapeXml(listName)}</ListName><ListInfo><Radio>0</Radio><SourceName>Deezer</SourceName><SearchUrl>${escapeXml(context?.url || info.list_url)}</SearchUrl><TrackNumber>${playable.length}</TrackNumber><Quality>0</Quality><Login_username>${escapeXml(info.user_name || '')}</Login_username><Login_password>${escapeXml(queuePassword)}</Login_password><UpdateTime>0</UpdateTime><LastPlayIndex>${startIndex + 1}</LastPlayIndex><SwitchPageMode>0</SwitchPageMode><CurrentPage>0</CurrentPage><TotalPages>0</TotalPages></ListInfo><Tracks>${tracks}</Tracks></PlayList>`;
    await this.linkplay.playQueueAction('CreateQueue', { QueueContext: queue });
    await this.linkplay.playQueueAction('PlayQueueWithIndex', { QueueName: listName, Index: String(startIndex + 1) });
  }
}

function cleanMessage(message) {
  const text = String(message ?? '').trim();
  return text && !/^(Auto_Define|not login|action timeout)$/i.test(text) ? text : '';
}

export function deezerEntry(entry, index) {
  return {
    key: `${entry.id || entry.url || entry.title || 'item'}-${index}`,
    title: entry.title || entry.name || 'Без названия',
    subtitle: [entry.artist?.title || entry.artist?.name || entry.artist, entry.album?.title || entry.album?.name || entry.album]
      .filter(value => typeof value === 'string' && value).join(' · '),
    artwork: imageURL(entry),
    url: entry.url || '',
    playable: Boolean(numericTrackId(entry)),
    raw: entry,
  };
}

export function deezerNavigation(root) {
  const content = root.content ?? root;
  const pagination = content.pagination ?? {};
  return { next: pagination.next || '', prev: pagination.prev || '' };
}
