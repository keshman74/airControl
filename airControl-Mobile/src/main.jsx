import React, { useRef, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { LinkplayClient } from './linkplay.js';
import { DeezerClient, deezerEntry, deezerNavigation } from './deezer.js';
import './style.css';

const tabs = [
  ['CurrentQueue', 'Сейчас играет'],
  ['USBDiskQueue', 'USB'],
  ['TotalQueue', 'Очереди'],
];

const statusLabels = { play: 'Воспроизведение', pause: 'Пауза', stop: 'Остановлено', load: 'Загрузка' };

function App() {
  const [host, setHost] = useState('192.168.0.29');
  const [device, setDevice] = useState(null);
  const [player, setPlayer] = useState(null);
  const [tab, setTab] = useState('CurrentQueue');
  const [queue, setQueue] = useState(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [section, setSection] = useState('queues');
  const [deezerInfo, setDeezerInfo] = useState(null);
  const [deezerRoot, setDeezerRoot] = useState(null);
  const [deezerItems, setDeezerItems] = useState([]);
  const [deezerURL, setDeezerURL] = useState('');
  const [deezerTrail, setDeezerTrail] = useState([]);
  const [deezerSearch, setDeezerSearch] = useState('');
  const [deezerSearchURL, setDeezerSearchURL] = useState('');
  const [deezerUsername, setDeezerUsername] = useState('');
  const [deezerPassword, setDeezerPassword] = useState('');
  const [deezerBusy, setDeezerBusy] = useState(false);
  const [deezerMessage, setDeezerMessage] = useState('');
  const client = useRef(null);
  const pending = useRef(false);
  const deezer = useRef(null);
  const deezerPending = useRef(false);

  async function load(nextTab, reconnect = false) {
    if (pending.current) return;
    pending.current = true;
    setBusy(true);
    setError('');
    setTab(nextTab);
    setQueue(null);
    if (reconnect) {
      client.current = null;
      deezer.current = null;
      setDevice(null);
      setPlayer(null);
      setDeezerInfo(null);
      setDeezerRoot(null);
      setDeezerItems([]);
      setDeezerTrail([]);
      setDeezerPassword('');
    }
    try {
      if (!client.current) {
        const connection = new LinkplayClient(host);
        setDevice(await connection.connect());
        client.current = connection;
      }
      const connection = client.current;
      const before = await connection.playerInfo('getPlayerStatus').catch(() => null);
      setPlayer(before);
      const snapshot = await connection.browse(nextTab);
      if (nextTab === 'CurrentQueue' && snapshot.activeIndex != null) {
        const after = await connection.playerInfo('getPlayerStatus').catch(() => null);
        setPlayer(after);
        const stable = before && after && ['status', 'mode', 'Title', 'Artist', 'Album', 'uri', 'plicurr']
          .every(field => before[field] === after[field]);
        if (!stable) snapshot.activeIndex = null;
      }
      setQueue(snapshot);
    } catch (failure) {
      setError(failure instanceof Error ? failure.message : 'Запрос к устройству не выполнен.');
    } finally {
      pending.current = false;
      setBusy(false);
    }
  }

  const activeIndex = tab === 'CurrentQueue' && player?.status === 'play' ? queue?.activeIndex : null;

  async function deezerTask(task) {
    if (deezerPending.current) return;
    deezerPending.current = true;
    setDeezerBusy(true);
    setDeezerMessage('');
    setError('');
    try { await task(); }
    catch (failure) { setDeezerMessage(failure instanceof Error ? failure.message : 'Запрос Deezer не выполнен.'); }
    finally { deezerPending.current = false; setDeezerBusy(false); }
  }

  async function openDeezer() {
    setSection('deezer');
    setDeezerRoot(null);
    setDeezerInfo(null);
    setDeezerItems([]);
    setDeezerTrail([]);
    setDeezerMessage('');
    await deezerTask(async () => {
      if (!client.current) {
        const connection = new LinkplayClient(host);
        const identity = await connection.connect();
        client.current = connection;
        setDevice(identity);
      }
      deezer.current = new DeezerClient(client.current);
      const info = await deezer.current.userInfo();
      if (deezer.current.ready(info)) {
        setDeezerInfo(info);
        await loadDeezerPage(info.list_url, info, false);
      }
    });
  }

  async function loadDeezerPage(address, info = deezerInfo, push = true, query = '') {
    const result = await deezer.current.page(info, address, query);
    if (push && deezerRoot) setDeezerTrail(previous => [...previous, { root: deezerRoot, url: deezerURL }]);
    setDeezerRoot(result.root);
    setDeezerURL(result.url);
    setDeezerItems(deezer.current.entries(result.root).map(deezerEntry));
    const searchEntry = deezer.current.entries(result.root).find(item => String(item.id || '').toLowerCase().includes('search'));
    setDeezerSearchURL(searchEntry?.url || info.list_url);
    setDeezerSearch('');
  }

  function browseDeezerItem(item) {
    if (item.playable) {
      deezerTask(async () => {
        const tracks = deezerItems.filter(entry => entry.playable).map(entry => entry.raw);
        const index = tracks.findIndex(entry => entry === item.raw);
        await deezer.current.play(tracks, index, deezerInfo, { ...deezerRoot, url: deezerURL });
        setDeezerMessage('Воспроизведение отправлено на устройство.');
      });
    } else if (item.url) {
      deezerTask(() => loadDeezerPage(item.url));
    }
  }

  function backDeezer() {
    const previous = deezerTrail.at(-1);
    if (!previous) return;
    setDeezerTrail(items => items.slice(0, -1));
    setDeezerRoot(previous.root);
    setDeezerURL(previous.url);
    setDeezerItems(deezer.current.entries(previous.root).map(deezerEntry));
  }

  function searchDeezer(event) {
    event.preventDefault();
    if (!deezerSearch.trim() || !deezerSearchURL) return;
    deezerTask(() => loadDeezerPage(deezerSearchURL, deezerInfo, true, deezerSearch.trim()));
  }

  return <main>
    <header><p className="brand">FILMOSCOPE LAB</p><h1>airControl <span>Mobile</span></h1><p className="intro">Очереди и медиатека в локальной сети</p></header>
    <form className="connection" onSubmit={event => { event.preventDefault(); load(tab, true); }}>
      <label htmlFor="host">IP-адрес устройства</label>
      <div className="connect-row"><input id="host" value={host} inputMode="decimal" autoCapitalize="none" spellCheck={false} onChange={event => setHost(event.target.value)} disabled={busy} />
      <button type="submit" disabled={busy}>Подключить</button></div>
    </form>
    {device && <section className="device" aria-label="Устройство">
      <div><strong>{device.DeviceName || 'Linkplay'}</strong><p>{device.hardware || 'Linkplay'} · {device.firmware}</p></div>
      <div><strong>{statusLabels[player?.status] || 'Статус недоступен'}</strong><p>{player?.vol != null ? `Громкость ${player.vol}%` : 'Громкость —'}</p></div>
    </section>}
    <nav aria-label="Раздел приложения">
      <button type="button" aria-pressed={section === 'queues'} onClick={() => setSection('queues')}>Очереди</button>
      <button type="button" aria-pressed={section === 'deezer'} disabled={busy || deezerBusy} onClick={openDeezer}>Deezer</button>
    </nav>
    {section === 'queues' && <>
    <nav aria-label="Очереди">
      {tabs.map(([name, label]) => <button key={name} type="button" aria-pressed={tab === name} disabled={busy || !device} onClick={() => load(name)}>{label}</button>)}
    </nav>
    {device && <button type="button" className="refresh" disabled={busy} onClick={() => load(tab)}>Обновить</button>}
    {busy && <p role="status">Читаю данные устройства…</p>}
    {error && <p role="alert" className="error">{error}</p>}
    {queue?.kind === 'catalog' && <section className="queue">
      <h2>Каталог очередей</h2>
      {queue.active && <p>Активная · {queue.active}</p>}
      <ul>{queue.entries.map((entry, index) => <li key={index}>{entry}</li>)}</ul>
      {!queue.entries.length && <p>Нет записей.</p>}
    </section>}
    {queue?.kind === 'playlist' && <section className="queue">
      <h2>{queue.name || queue.source || 'Плейлист'}</h2>
      <p>Треков · {queue.tracks.length}</p>
      <ol className="tracks">{queue.tracks.map((track, index) => <li key={index} className={activeIndex === index ? 'active' : undefined} aria-current={activeIndex === index ? 'true' : undefined}>
        {track.artwork && <img src={track.artwork} alt="" loading="lazy" referrerPolicy="no-referrer" onError={event => { event.currentTarget.hidden = true; }} />}
        <div><strong>{track.title}</strong>{(track.artist || track.album) && <p>{[track.artist, track.album].filter(Boolean).join(' · ')}</p>}</div>
      </li>)}</ol>
      {!queue.tracks.length && <p>Очередь пуста.</p>}
    </section>}
    </>}
    {section === 'deezer' && <section className="queue deezer">
      <div className="deezer-heading"><div><h2>Deezer</h2><p>{device?.DeviceName || 'Сначала подключитесь к устройству'}</p></div>
        {deezerTrail.length > 0 && <button type="button" disabled={deezerBusy} onClick={backDeezer}>Назад</button>}
      </div>
      {!deezerInfo && <form className="deezer-login" onSubmit={event => { event.preventDefault(); deezerTask(async () => {
        if (!client.current) {
          const connection = new LinkplayClient(host);
          const identity = await connection.connect();
          client.current = connection;
          setDevice(identity);
        }
        deezer.current = new DeezerClient(client.current);
        const info = await deezer.current.login(deezerUsername, deezerPassword);
        setDeezerInfo(info);
        setDeezerPassword('');
        await loadDeezerPage(info.list_url, info, false);
      }); }}>
        <label htmlFor="deezer-user">Логин или почта Deezer</label><input id="deezer-user" value={deezerUsername} autoComplete="username" onChange={event => setDeezerUsername(event.target.value)} disabled={deezerBusy} />
        <label htmlFor="deezer-password">Пароль</label><input id="deezer-password" type="password" value={deezerPassword} autoComplete="current-password" onChange={event => setDeezerPassword(event.target.value)} disabled={deezerBusy} />
        <button type="submit" disabled={deezerBusy || !device}>Войти на устройстве</button>
      </form>}
      {deezerInfo && <>
        <form className="deezer-search" onSubmit={searchDeezer}><input aria-label="Поиск Deezer" placeholder="Поиск в Deezer" value={deezerSearch} onChange={event => setDeezerSearch(event.target.value)} disabled={deezerBusy} /><button type="submit" disabled={deezerBusy || !deezerSearch.trim()}>Найти</button></form>
        {deezerRoot && <h3>{deezerRoot.title || deezerRoot.name || 'Медиатека'}</h3>}
        <ul className="deezer-list">{deezerItems.map(item => <li key={item.key}><button type="button" disabled={deezerBusy || (!item.playable && !item.url)} onClick={() => browseDeezerItem(item)}>
          {item.artwork && <img src={item.artwork} alt="" loading="lazy" referrerPolicy="no-referrer" onError={event => { event.currentTarget.hidden = true; }} />}
          <span><strong>{item.title}</strong>{item.subtitle && <small>{item.subtitle}</small>}</span><span className="deezer-action">{item.playable ? '▶' : item.url ? '›' : ''}</span>
        </button></li>)}</ul>
        {!deezerItems.length && deezerRoot && <p>В этом разделе пока нет записей.</p>}
        {(() => { const navigation = deezerRoot ? deezerNavigation(deezerRoot) : {}; return navigation.next ? <button type="button" disabled={deezerBusy} onClick={() => deezerTask(() => loadDeezerPage(navigation.next))}>Следующая страница</button> : null; })()}
      </>}
      {deezerBusy && <p role="status">Связываюсь с Deezer…</p>}
      {deezerMessage && <p role="alert" className={deezerMessage.includes('отправлено') ? 'success' : 'error'}>{deezerMessage}</p>}
    </section>}
  </main>;
}

createRoot(document.getElementById('root')).render(<App />);
