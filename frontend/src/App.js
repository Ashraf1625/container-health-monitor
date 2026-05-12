import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import axios from 'axios';
import {
  Bar, BarChart, CartesianGrid, Cell,
  Legend, Line, LineChart,
  ResponsiveContainer, Tooltip, XAxis, YAxis,
} from 'recharts';
import './App.css';

// ─── API helpers ────────────────────────────────────────────────────────────

function apiBase() {
  const v = process.env.REACT_APP_API_URL;
  if (!v || String(v).trim() === '') return '';
  return String(v).replace(/\/$/, '');
}

function grafanaUrl() {
  const e = (process.env.REACT_APP_GRAFANA_URL || '').trim();
  if (e) return e.replace(/\/$/, '');
  if (typeof window !== 'undefined') {
    return `${window.location.protocol}//${window.location.hostname}:3001`;
  }
  return 'http://localhost:3001';
}

// ─── Status badge ────────────────────────────────────────────────────────────

const BADGE_CLASS = {
  running:    'badge-run',
  exited:     'badge-exit',
  paused:     'badge-pause',
  restarting: 'badge-restart',
};

function Badge({ status }) {
  const cls = BADGE_CLASS[status] || 'badge-def';
  return <span className={`badge ${cls}`}>{status}</span>;
}

// ─── Progress bar ────────────────────────────────────────────────────────────

function Gauge({ value, warm }) {
  const pct = Math.min(Math.max(Number(value) || 0, 0), 100);
  let color = warm === 'mem' ? '#2bb0c7' : '#3d7eef';
  if (pct > 80)      color = '#e5534b';
  else if (pct > 60) color = '#e5a11a';

  return (
    <div className="gauge-row">
      <div className="track">
        <div className="fill" style={{ width: `${pct}%`, background: color }} />
      </div>
      <span className="pct">{pct.toFixed(1)}%</span>
    </div>
  );
}

// ─── Container card ──────────────────────────────────────────────────────────

function Card({ c, busy, onStop, onRestart }) {
  const running = c.status === 'running';
  const healthBadge = c.health && c.health !== 'none'
    ? <span className={`health-dot ${c.health}`} title={`Health: ${c.health}`} />
    : null;

  return (
    <article className="card">
      <div className="card-top">
        <div className="card-name-block">
          <div className="card-name">{c.name}{healthBadge}</div>
          <div className="card-image">{c.image}</div>
          {c.network && <div className="card-network">🌐 {c.network}</div>}
        </div>
        <Badge status={c.status} />
      </div>

      <div className="metric-block">
        <div className="metric-label">CPU</div>
        <Gauge value={c.cpu_percent} />
      </div>

      <div className="metric-block">
        <div className="metric-label">
          Memory — {c.mem_usage_mb} / {c.mem_limit_mb} MB
        </div>
        <Gauge value={c.mem_percent} warm="mem" />
      </div>

      <div className="card-meta">
        <span>Restarts: <strong>{c.restart_count}</strong></span>
        <span>Health: <strong>{c.health || '—'}</strong></span>
      </div>

      <div className="card-actions">
        <button
          id={`btn-stop-${c.name}`}
          className="btn btn-danger"
          disabled={!running || busy}
          onClick={() => onStop(c.name)}
        >
          ⏹ Stop
        </button>
        <button
          id={`btn-restart-${c.name}`}
          className="btn btn-primary"
          disabled={busy}
          onClick={() => onRestart(c.name)}
        >
          🔄 Restart
        </button>
      </div>
    </article>
  );
}

// ─── Events log ──────────────────────────────────────────────────────────────

function EventLog({ items }) {
  const typeClass = (t) => ({ STOP: 't-stop', RESTART: 't-restart', INFO: 't-info' }[t] || 't-def');

  return (
    <section className="panel" id="events-panel">
      <h2 className="panel-title">📋 Operations Log <span className="badge-count">{items.length}</span></h2>
      {items.length === 0 ? (
        <p className="empty-msg">No operations recorded yet.</p>
      ) : (
        <div className="event-list">
          {items.map((e, i) => (
            <div className="ev-row" key={`${e.timestamp}-${e.container}-${i}`}>
              <span className={`ev-type ${typeClass(e.type)}`}>{e.type}</span>
              <span className="ev-container">{e.container}</span>
              <span className="ev-msg">{e.message}</span>
              <span className="ev-time">{e.timestamp ? new Date(e.timestamp).toLocaleString() : ''}</span>
            </div>
          ))}
        </div>
      )}
    </section>
  );
}

// ─── Bar chart (snapshot) ────────────────────────────────────────────────────

function ResourceChart({ containers }) {
  const data = useMemo(
    () =>
      containers
        .filter((x) => x.status === 'running')
        .map((x) => ({
          name: x.name.length > 16 ? `${x.name.slice(0, 14)}…` : x.name,
          cpu: parseFloat(x.cpu_percent.toFixed(1)),
          mem: parseFloat(x.mem_percent.toFixed(1)),
        })),
    [containers],
  );

  if (!data.length) return null;

  return (
    <section className="panel" id="chart-panel">
      <h2 className="panel-title">📊 Resource Usage (running containers)</h2>
      <div className="chart-wrap">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={data} margin={{ top: 8, right: 16, left: 0, bottom: 8 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#252a36" />
            <XAxis dataKey="name" tick={{ fill: '#8b93a7', fontSize: 11 }} angle={-10} textAnchor="end" height={48} />
            <YAxis domain={[0, 100]} width={36} tick={{ fill: '#8b93a7', fontSize: 11 }} unit="%" />
            <Tooltip
              contentStyle={{ background: '#12151c', border: '1px solid #252a36', borderRadius: 8, fontSize: 12 }}
              formatter={(v, name) => [`${Number(v).toFixed(1)}%`, name === 'cpu' ? 'CPU' : 'Memory']}
            />
            <Legend formatter={(v) => v === 'cpu' ? 'CPU %' : 'Memory %'} wrapperStyle={{ fontSize: 12, color: '#8b93a7' }} />
            <Bar dataKey="cpu" name="cpu" radius={[4, 4, 0, 0]}>
              {data.map((_, i) => <Cell key={`cpu-${i}`} fill="#3d7eef" />)}
            </Bar>
            <Bar dataKey="mem" name="mem" radius={[4, 4, 0, 0]}>
              {data.map((_, i) => <Cell key={`mem-${i}`} fill="#2bb0c7" />)}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>
    </section>
  );
}

// ─── Time-series sparkline (last 20 polls) ───────────────────────────────────

function TrendChart({ history }) {
  if (history.length < 2) return null;

  return (
    <section className="panel" id="trend-panel">
      <h2 className="panel-title">📈 Average CPU & Memory Trend (last 20 snapshots)</h2>
      <div className="chart-wrap">
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={history} margin={{ top: 8, right: 16, left: 0, bottom: 4 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#252a36" />
            <XAxis dataKey="ts" tick={{ fill: '#8b93a7', fontSize: 10 }} />
            <YAxis domain={[0, 100]} width={36} tick={{ fill: '#8b93a7', fontSize: 11 }} unit="%" />
            <Tooltip
              contentStyle={{ background: '#12151c', border: '1px solid #252a36', borderRadius: 8, fontSize: 12 }}
              formatter={(v, name) => [`${Number(v).toFixed(1)}%`, name === 'avgCpu' ? 'Avg CPU' : 'Avg Memory']}
            />
            <Legend formatter={(v) => v === 'avgCpu' ? 'Avg CPU %' : 'Avg Memory %'} wrapperStyle={{ fontSize: 12, color: '#8b93a7' }} />
            <Line type="monotone" dataKey="avgCpu" name="avgCpu" stroke="#3d7eef" strokeWidth={2} dot={false} />
            <Line type="monotone" dataKey="avgMem" name="avgMem" stroke="#2bb0c7" strokeWidth={2} dot={false} />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </section>
  );
}

// ─── Error parser ─────────────────────────────────────────────────────────────

function parseErr(err) {
  const d = err?.response?.data?.detail;
  if (typeof d === 'string') return d;
  if (Array.isArray(d)) return d.map((x) => x.msg || JSON.stringify(x)).join('; ');
  return err?.message || 'Request failed';
}

// ─── Main App ─────────────────────────────────────────────────────────────────

export default function App() {
  const API = apiBase();
  const [rows,     setRows]    = useState([]);
  const [events,   setEvents]  = useState([]);
  const [history,  setHistory] = useState([]);
  const [loading,  setLoading] = useState(true);
  const [busy,     setBusy]    = useState(false);
  const [err,      setErr]     = useState('');
  const [lastPoll, setLastPoll]= useState('');
  const [simOn,    setSimOn]   = useState(false);
  const histRef = useRef([]);

  const load = useCallback(async () => {
    try {
      const [cr, er] = await Promise.all([
        axios.get(`${API}/containers`),
        axios.get(`${API}/events`),
      ]);
      const containers = Array.isArray(cr.data) ? cr.data : [];
      setRows(containers);
      setEvents(Array.isArray(er.data) ? er.data : []);
      setLastPoll(new Date().toLocaleTimeString());
      setErr('');

      // build history point
      const running = containers.filter((c) => c.status === 'running');
      if (running.length) {
        const avgCpu = running.reduce((s, c) => s + c.cpu_percent, 0) / running.length;
        const avgMem = running.reduce((s, c) => s + c.mem_percent, 0) / running.length;
        const point  = { ts: new Date().toLocaleTimeString(), avgCpu, avgMem };
        histRef.current = [...histRef.current.slice(-19), point];
        setHistory([...histRef.current]);
      }
    } catch (e) {
      setErr(parseErr(e));
    } finally {
      setLoading(false);
    }
  }, [API]);

  useEffect(() => {
    load();
    const id = setInterval(load, 5000);
    return () => clearInterval(id);
  }, [load]);

  const act = async (path, onSuccess) => {
    setBusy(true);
    setErr('');
    try {
      await axios.post(`${API}${path}`);
      if (onSuccess) onSuccess();
      await load();
    } catch (e) {
      setErr(parseErr(e));
    } finally {
      setBusy(false);
    }
  };

  const onStop    = (name) => act(`/containers/${encodeURIComponent(name)}/stop`);
  const onRestart = (name) => act(`/containers/${encodeURIComponent(name)}/restart`);
  const onStartSim = () => act('/simulation/start', () => setSimOn(true));
  const onStopSim  = () => act('/simulation/stop',  () => setSimOn(false));

  const totalCount   = rows.length;
  const runningCount = rows.filter((r) => r.status === 'running').length;
  const stoppedCount = totalCount - runningCount;
  const avgCpu = runningCount
    ? (rows.filter(r => r.status === 'running').reduce((s, c) => s + c.cpu_percent, 0) / runningCount).toFixed(1)
    : '0.0';

  return (
    <div className="app" id="app-root">
      {/* ── HEADER ── */}
      <header className="header">
        <div className="header-brand">
          <div className="brand-icon">🐳</div>
          <div>
            <h1 className="brand-title">Container Health Monitor</h1>
            <p className="brand-sub">
              CSE 363 · Cloud Computing · Galala University
            </p>
          </div>
        </div>
        <div className="header-controls">
          <div className="poll-info">
            <span className="poll-label">Auto-refresh: 5 s</span>
            <span className="poll-time">Last: {lastPoll || '—'}</span>
          </div>
          <div className="sim-controls">
            <button
              id="btn-start-sim"
              className={`btn btn-primary ${simOn ? 'btn-active' : ''}`}
              onClick={onStartSim}
              disabled={busy}
            >
              ▶ Start Load Sim
            </button>
            <button
              id="btn-stop-sim"
              className="btn btn-danger"
              onClick={onStopSim}
              disabled={busy}
            >
              ■ Stop Load Sim
            </button>
          </div>
        </div>
      </header>

      {/* ── ERROR BANNER ── */}
      {err && (
        <div className="alert-banner" role="alert" id="error-banner">
          ⚠ {err}
        </div>
      )}

      {/* ── SUMMARY STATS ── */}
      <section className="stats-row" aria-label="Summary statistics">
        <div className="stat-card stat-total">
          <div className="stat-label">Total Containers</div>
          <div className="stat-value">{totalCount}</div>
        </div>
        <div className="stat-card stat-running">
          <div className="stat-label">Running</div>
          <div className="stat-value">{runningCount}</div>
        </div>
        <div className="stat-card stat-stopped">
          <div className="stat-label">Stopped / Exited</div>
          <div className="stat-value">{stoppedCount}</div>
        </div>
        <div className="stat-card stat-cpu">
          <div className="stat-label">Avg CPU (running)</div>
          <div className="stat-value">{avgCpu}%</div>
        </div>
      </section>

      {/* ── CHARTS ── */}
      {!loading && rows.length > 0 && <ResourceChart containers={rows} />}
      {history.length >= 2 && <TrendChart history={history} />}

      {/* ── CONTAINER GRID ── */}
      <section className="container-grid" aria-label="Container cards" id="container-grid">
        {loading ? (
          <div className="loading-state">
            <div className="spinner" aria-hidden />
            Loading containers…
          </div>
        ) : rows.length === 0 ? (
          <div className="empty-state">
            No containers found. Ensure Docker socket is mounted and the backend
            is running inside Linux (Ubuntu VM / WSL2).
          </div>
        ) : (
          rows.map((c) => (
            <Card key={c.id} c={c} busy={busy} onStop={onStop} onRestart={onRestart} />
          ))
        )}
      </section>

      {/* ── EVENTS LOG ── */}
      <EventLog items={events} />

      {/* ── FOOTER ── */}
      <footer className="footer">
        <a href={grafanaUrl()} target="_blank" rel="noopener noreferrer" id="link-grafana">
          📊 Grafana Dashboard :3001
        </a>
        <a href={`${API}/docs`} target="_blank" rel="noopener noreferrer" id="link-apidocs">
          📄 OpenAPI Docs
        </a>
        <a href="http://localhost:9090" target="_blank" rel="noopener noreferrer" id="link-prometheus">
          🔥 Prometheus :9090
        </a>
        <span className="footer-note">CSE 363 — Cloud Computing · Galala University</span>
      </footer>
    </div>
  );
}
