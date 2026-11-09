import React, { useRef, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { LinkplayClient } from './linkplay.js';
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
  const client = useRef(null);
  const pending = useRef(false);

  async function load(nextTab, reconnect = false) {
    if (pending.current) return;
    pending.current = true;
    setBusy(true);
    setError('');
    setTab(nextTab);
    setQueue(null);
    if (reconnect) {
      client.current = null;
      setDevice(null);
      setPlayer(null);
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
  </main>;
}

createRoot(document.getElementById('root')).render(<App />);
