// ui_kits/reservives_app/components.jsx
// Small, reusable presentational components for the Reservives app kit.
// Loaded as a Babel script — exports are pinned onto window.

const { useState, useEffect, useRef } = React;

/* ── Top app bar ────────────────────────────────────────────────────── */
function AppBar({ title, onBack, actions }) {
  return (
    <header className="appbar">
      {onBack && (
        <button className="back" onClick={onBack} aria-label="Back">
          <span className="material-symbols-rounded">arrow_back</span>
        </button>
      )}
      <h1>{title}</h1>
      {actions}
    </header>
  );
}

function GhostIcon({ icon, onClick, badge }) {
  return (
    <button className="ghost" onClick={onClick} style={{ position:'relative' }}>
      <span className="material-symbols-rounded">{icon}</span>
      {badge ? <span style={{
        position:'absolute', top:6, right:6, width:8, height:8,
        background:'var(--rv-error)', borderRadius:'50%',
        boxShadow:'0 0 0 2px #fff'
      }}/> : null}
    </button>
  );
}

/* ── Bottom navigation ──────────────────────────────────────────────── */
function BottomBar({ active, onChange }) {
  const items = [
    { id: 'home',     icon: 'home',         label: 'Inicio'    },
    { id: 'reservas', icon: 'event',        label: 'Reservas'  },
    { id: 'cafeteria',icon: 'restaurant',   label: 'Cafetería' },
    { id: 'asistente',icon: 'auto_awesome', label: 'IA'        },
    { id: 'perfil',   icon: 'person',       label: 'Perfil'    },
  ];
  return (
    <nav className="bottombar">
      {items.map(it => (
        <button key={it.id} className={active === it.id ? 'active' : ''} onClick={() => onChange(it.id)}>
          <span className="material-symbols-rounded">{it.icon}</span>
          <span>{it.label}</span>
        </button>
      ))}
    </nav>
  );
}

/* ── Polls banner (the only true gradient surface) ──────────────────── */
function PollsBanner({ count, onTap }) {
  return (
    <div className="polls-banner" onClick={onTap}>
      <div className="ico"><span className="material-symbols-rounded">how_to_vote</span></div>
      <div style={{ flex: 1 }}>
        <h3>Tienes {count} {count === 1 ? 'encuesta activa' : 'encuestas activas'}</h3>
        <p>Tu opinión configura cómo funciona el centro.</p>
      </div>
      <div className="arrow"><span className="material-symbols-rounded">chevron_right</span></div>
    </div>
  );
}

/* ── Activity (booking) row ─────────────────────────────────────────── */
function ActivityRow({ booking, onTap }) {
  const colorByStatus = {
    aprobada:   'var(--rv-success)',
    pendiente:  'var(--rv-warning)',
    rechazada:  'var(--rv-error)',
    cancelada:  'var(--rv-error)',
  };
  const c = colorByStatus[booking.status] || 'var(--rv-accent)';
  return (
    <div className="activity card tap" onClick={onTap} style={{ padding: 0 }}>
      <div className="stripe" style={{ background: c }} />
      <div className="date">
        <div className="name" style={{ color: c }}>{booking.dayName}</div>
        <div className="num">{booking.day}</div>
        <div className="mon">{booking.month}</div>
      </div>
      <div className="info">
        <div className="t">{booking.title}</div>
        <div className="m">
          <span className="material-symbols-rounded">schedule</span>
          {booking.time}{booking.statusLabel ? ` · ${booking.statusLabel}` : ''}
        </div>
      </div>
      <div className="chev"><span className="material-symbols-rounded">chevron_right</span></div>
    </div>
  );
}

/* ── Generic list tile ──────────────────────────────────────────────── */
function Tile({ icon, title, subtitle, onTap, trailing }) {
  return (
    <div className="tile card tap" onClick={onTap} style={{ padding: '14px 16px' }}>
      <div className="ico"><span className="material-symbols-rounded">{icon}</span></div>
      <div className="body">
        <div className="t">{title}</div>
        {subtitle && <div className="s">{subtitle}</div>}
      </div>
      {trailing || <div className="chev"><span className="material-symbols-rounded">chevron_right</span></div>}
    </div>
  );
}

/* ── Section header ─────────────────────────────────────────────────── */
function SectionTitle({ title, more, onMore }) {
  return (
    <div className="section-title">
      <h2>{title}</h2>
      {more && <button className="more" onClick={onMore}>{more}</button>}
    </div>
  );
}

/* ── Toast ──────────────────────────────────────────────────────────── */
function Toast({ kind, message, onDone }) {
  useEffect(() => {
    if (!message) return;
    const t = setTimeout(onDone, 2400);
    return () => clearTimeout(t);
  }, [message, onDone]);
  if (!message) return null;
  const tone = {
    success: { color: 'var(--rv-success)', icon: 'check_circle' },
    warning: { color: 'var(--rv-warning)', icon: 'warning' },
    error:   { color: 'var(--rv-error)',   icon: 'error' },
    info:    { color: 'var(--rv-accent)',  icon: 'info' },
  }[kind] || { color: 'var(--rv-accent)', icon: 'info' };
  return (
    <div className="toast">
      <span className="material-symbols-rounded" style={{ color: tone.color }}>{tone.icon}</span>
      <div className="msg">{message}</div>
    </div>
  );
}

/* ── Confirm dialog ─────────────────────────────────────────────────── */
function ConfirmDialog({ title, body, confirmLabel = 'Sí', cancelLabel = 'No', onConfirm, onCancel }) {
  return (
    <div className="dialog-scrim" onClick={onCancel}>
      <div className="dialog" onClick={e => e.stopPropagation()}>
        <div className="halo"><span className="material-symbols-rounded">help</span></div>
        <h3>{title}</h3>
        <p>{body}</p>
        <div className="row">
          <button className="btn-outline" onClick={onCancel}>{cancelLabel}</button>
          <button className="btn-primary" onClick={onConfirm}>{confirmLabel}</button>
        </div>
      </div>
    </div>
  );
}

/* ── Empty state ────────────────────────────────────────────────────── */
function EmptyState({ icon, title, body, ctaLabel, onCta }) {
  return (
    <div className="empty">
      <div className="halo"><div className="core"><span className="material-symbols-rounded">{icon}</span></div></div>
      <h3>{title}</h3>
      <p>{body}</p>
      {ctaLabel && (
        <div style={{ width: 200, margin: '0 auto' }}>
          <button className="btn-primary" onClick={onCta}>
            <span className="material-symbols-rounded">add</span>{ctaLabel}
          </button>
        </div>
      )}
    </div>
  );
}

Object.assign(window, {
  AppBar, GhostIcon, BottomBar, PollsBanner,
  ActivityRow, Tile, SectionTitle,
  Toast, ConfirmDialog, EmptyState,
});
