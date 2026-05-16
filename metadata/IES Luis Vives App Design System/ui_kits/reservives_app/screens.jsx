// ui_kits/reservives_app/screens.jsx
// Screen-level compositions wired to fake state.

const { useState: useStateS, useMemo } = React;

/* ── Login ──────────────────────────────────────────────────────────── */
function LoginScreen({ onSignIn, onGuest, loadingMs, loadingGuest }) {
  return (
    <div className="screen" style={{ position:'relative' }}>
      <div className="bg-anim">
        <div className="blob b1"></div>
        <div className="blob b2"></div>
      </div>
      <div className="login-wrap" style={{ position:'relative' }}>
        <div className="login-logo">
          <img src="../../assets/logo_luis_vives.png" alt="IES Luis Vives" />
        </div>
        <div className="login-title">
          <div className="ey">bienvenido/a a</div>
          <div className="h">Reservives — IES Luis Vives</div>
        </div>
        <div className="login-card">
          <button className="btn-primary" onClick={onSignIn} disabled={loadingMs}>
            {loadingMs ? 'Conectando…' : (
              <React.Fragment>
                <img src="../../assets/microsoft_icon.png" alt="" style={{ width: 22, height: 22 }} />
                Iniciar sesión con Microsoft
              </React.Fragment>
            )}
          </button>
          <div className="or">o</div>
          <button className="btn-outline" onClick={onGuest} disabled={loadingGuest}>
            {loadingGuest ? 'Entrando…' : 'Continuar sin cuenta'}
          </button>
        </div>
        <div style={{ fontSize: 11, color: 'var(--rv-muted)', textAlign:'center', marginTop:'auto' }}>
          v1.0 · vms.iesluisvives.org
        </div>
      </div>
    </div>
  );
}

/* ── Home ───────────────────────────────────────────────────────────── */
function HomeScreen({ user, bookings, onOpenPolls, onOpenBooking, onSeeAll, onNotif }) {
  const greeting = (() => {
    const h = new Date().getHours();
    if (h < 12) return 'Buenos días';
    if (h < 20) return 'Buenas tardes';
    return 'Buenas noches';
  })();
  return (
    <React.Fragment>
      <AppBar
        title="Inicio"
        actions={
          <React.Fragment>
            <GhostIcon icon="search" />
            <GhostIcon icon="notifications" badge onClick={onNotif} />
          </React.Fragment>
        }
      />
      <div className="screen fade-in">
        <div style={{ padding: '8px 20px 4px' }}>
          <div className="eyebrow">{greeting.toLowerCase()}</div>
          <h1 style={{ margin: '4px 0 0', font: '900 30px/1.05 var(--rv-font)', letterSpacing: '-1.2px' }}>
            {user.name}
          </h1>
          <div style={{ marginTop: 8, color: 'var(--rv-muted)', font: '400 13.5px/1.4 var(--rv-font)' }}>
            Tienes <b style={{ color: 'var(--rv-accent)' }}>{user.tokens} tokens</b> disponibles esta semana.
          </div>
        </div>

        <div style={{ marginTop: 20 }}>
          <PollsBanner count={2} onTap={onOpenPolls} />
        </div>

        <SectionTitle title="Próximas reservas" more={`Ver todas (${bookings.length})`} onMore={onSeeAll} />
        <div className="col">
          {bookings.slice(0, 3).map(b => (
            <ActivityRow key={b.id} booking={b} onTap={() => onOpenBooking(b)} />
          ))}
        </div>

        <SectionTitle title="Tablón" more="Ver todo" />
        <div className="col" style={{ paddingBottom: 24 }}>
          <div className="card tap">
            <div style={{ display:'flex', gap:8, alignItems:'center' }}>
              <span className="badge accent"><span className="material-symbols-rounded">push_pin</span>DESTACADO</span>
              <span style={{ font:'500 11px var(--rv-font)', color:'var(--rv-muted)' }}>Hace 2 horas · Dirección</span>
            </div>
            <div style={{ font: '700 15px/1.3 var(--rv-font)', marginTop: 10 }}>
              Cambio de horario en cafetería esta semana
            </div>
            <div style={{ font: '400 13px/1.5 var(--rv-font)', color:'var(--rv-muted)', marginTop: 4 }}>
              Por obras en el patio, la cafetería abrirá a las 8:30 y cerrará a las 16:00 hasta el viernes.
            </div>
          </div>
          <div className="card tap">
            <div style={{ display:'flex', gap:8, alignItems:'center' }}>
              <span className="badge success">EVENTO</span>
              <span style={{ font:'500 11px var(--rv-font)', color:'var(--rv-muted)' }}>Mañana · Departamento de música</span>
            </div>
            <div style={{ font: '700 15px/1.3 var(--rv-font)', marginTop: 10 }}>
              Ensayo abierto del coro — todos invitados
            </div>
          </div>
        </div>
      </div>
    </React.Fragment>
  );
}

/* ── Reservas (lista de espacios) ───────────────────────────────────── */
function ReservasScreen({ onOpenSpace }) {
  const [q, setQ] = useStateS('');
  const spaces = [
    { id: 's1', name: 'Aula multimedia 204',     cat: 'Aulas',     icon: 'class',          tokens: 1, free: true },
    { id: 's2', name: 'Pista de pádel cubierta', cat: 'Deportivo', icon: 'sports_tennis',  tokens: 2, free: true },
    { id: 's3', name: 'Salón de actos',          cat: 'Eventos',   icon: 'theaters',       tokens: 4, free: false },
    { id: 's4', name: 'Sala de profesores',      cat: 'Reuniones', icon: 'meeting_room',   tokens: 1, free: true },
    { id: 's5', name: 'Laboratorio de física',   cat: 'Aulas',     icon: 'science',        tokens: 1, free: true },
    { id: 's6', name: 'Polideportivo',           cat: 'Deportivo', icon: 'sports_handball',tokens: 2, free: false },
  ];
  const filtered = spaces.filter(s => s.name.toLowerCase().includes(q.toLowerCase()));
  return (
    <React.Fragment>
      <AppBar title="Reservas" actions={<GhostIcon icon="filter_list" />} />
      <div className="screen fade-in" style={{ paddingBottom: 24 }}>
        <div style={{ padding: '6px 20px 0' }}>
          <div className="search">
            <span className="material-symbols-rounded">search</span>
            <input placeholder="Buscar espacios o servicios…" value={q} onChange={e => setQ(e.target.value)} />
          </div>
        </div>
        <div className="cat-row" style={{ paddingTop: 16, paddingBottom: 4 }}>
          {['Todos','Aulas','Deportivo','Eventos','Reuniones'].map((c, i) => (
            <div key={c} className={'cat' + (i === 0 ? ' active' : '')}>{c}</div>
          ))}
        </div>
        <SectionTitle title={`${filtered.length} espacios`} />
        <div className="col">
          {filtered.map(s => (
            <Tile
              key={s.id}
              icon={s.icon}
              title={s.name}
              subtitle={`${s.cat} · ${s.tokens} ${s.tokens === 1 ? 'token' : 'tokens'}/reserva`}
              onTap={() => onOpenSpace(s)}
              trailing={
                <span className={'badge ' + (s.free ? 'success' : 'warn')}>
                  {s.free ? 'DISPONIBLE' : 'POCAS PLAZAS'}
                </span>
              }
            />
          ))}
        </div>
      </div>
    </React.Fragment>
  );
}

/* ── Detalle de espacio + selección de slot ─────────────────────────── */
function SpaceDetailScreen({ space, onBack, onConfirm }) {
  const [day, setDay] = useStateS(0);
  const [slot, setSlot] = useStateS(null);
  const days = useMemo(() => {
    const out = []; const base = new Date();
    const names = ['DOM','LUN','MAR','MIÉ','JUE','VIE','SÁB'];
    const months = ['ENE','FEB','MAR','ABR','MAY','JUN','JUL','AGO','SEP','OCT','NOV','DIC'];
    for (let i = 0; i < 7; i++) {
      const d = new Date(base); d.setDate(base.getDate() + i);
      out.push({ name: names[d.getDay()], num: d.getDate(), mon: months[d.getMonth()] });
    }
    return out;
  }, []);
  const slots = [
    { h: '08:00 - 09:00', taken: true  },
    { h: '09:00 - 10:00', taken: false },
    { h: '10:00 - 11:00', taken: false },
    { h: '11:30 - 12:30', taken: false },
    { h: '12:30 - 13:30', taken: true  },
    { h: '13:30 - 14:30', taken: false },
    { h: '16:00 - 17:00', taken: false },
    { h: '17:00 - 18:00', taken: false },
  ];
  return (
    <React.Fragment>
      <AppBar title={space.name} onBack={onBack} actions={<GhostIcon icon="bookmark_border" />} />
      <div className="screen fade-in" style={{ paddingBottom: 100 }}>
        <div style={{ padding: '4px 20px 0' }}>
          <div style={{
            background: 'linear-gradient(135deg,#FAD7E5,#F4A1C0)',
            borderRadius: 20, height: 140, display:'flex', alignItems:'center', justifyContent:'center',
            color: 'var(--rv-accent)'
          }}>
            <span className="material-symbols-rounded" style={{ fontSize: 64 }}>{space.icon}</span>
          </div>
          <div style={{ display:'flex', gap:8, marginTop:14, flexWrap:'wrap' }}>
            <span className="badge accent">{space.cat.toUpperCase()}</span>
            <span className="badge accent">{space.tokens} {space.tokens === 1 ? 'TOKEN' : 'TOKENS'}/RESERVA</span>
            <span className="badge success">DISPONIBLE</span>
          </div>
          <div style={{ font:'400 13.5px/1.5 var(--rv-font)', color:'var(--rv-muted)', marginTop: 12 }}>
            Espacio gestionado por el departamento. Las reservas recurrentes requieren aprobación de jefatura.
          </div>
        </div>

        <SectionTitle title="Elige un día" />
        <div className="days">
          {days.map((d, i) => (
            <div key={i} className={'day' + (day === i ? ' active' : '')} onClick={() => setDay(i)}>
              <div className="name">{d.name}</div>
              <div className="num">{d.num}</div>
              <div className="mon">{d.mon}</div>
            </div>
          ))}
        </div>

        <SectionTitle title="Tramos horarios" />
        <div className="slot-grid">
          {slots.map((s, i) => (
            <div key={i}
                 className={'slot' + (s.taken ? ' taken' : '') + (slot === i ? ' selected' : '')}
                 onClick={() => !s.taken && setSlot(i)}>
              <div className="h">{s.h}</div>
              <div className="s">{s.taken ? 'Ocupado' : 'Libre · 1 plaza'}</div>
            </div>
          ))}
        </div>
      </div>
      <div style={{
        position:'absolute', left: 16, right: 16, bottom: 76,
        background:'rgba(255,255,255,.95)', borderRadius: 18, padding: 12,
        boxShadow: 'var(--rv-shadow-deep)', backdropFilter:'blur(10px)',
        display:'flex', alignItems:'center', gap:10
      }}>
        <div style={{ flex:1 }}>
          <div className="eyebrow">total</div>
          <div style={{ font:'700 15px var(--rv-font)' }}>
            {slot != null ? `${days[day].name} ${days[day].num} · ${slots[slot].h}` : 'Selecciona un tramo'}
          </div>
        </div>
        <button className="btn-primary" disabled={slot == null}
                style={{ width: 'auto', padding: '14px 18px' }}
                onClick={() => onConfirm({ day: days[day], slot: slots[slot], space })}>
          Reservar
        </button>
      </div>
    </React.Fragment>
  );
}

/* ── Cafetería ──────────────────────────────────────────────────────── */
function CafeteriaScreen() {
  const [cat, setCat] = useStateS('Hoy');
  const cats = ['Hoy', 'Bocadillos', 'Bebidas', 'Snacks', 'Postres'];
  const items = [
    { t: 'Bocadillo de jamón',      s: 'Pan rústico · jamón serrano',    p: '2,80 €', icon:'lunch_dining' },
    { t: 'Tortilla de patata',      s: 'Pincho cuadrado',                p: '1,80 €', icon:'egg_alt' },
    { t: 'Empanada gallega',        s: 'Atún o carne',                   p: '2,40 €', icon:'breakfast_dining' },
    { t: 'Zumo natural',            s: 'Naranja recién exprimida',       p: '1,60 €', icon:'local_drink' },
    { t: 'Café con leche',          s: 'Espresso doble + leche',         p: '1,30 €', icon:'coffee' },
  ];
  return (
    <React.Fragment>
      <AppBar title="Cafetería" actions={<GhostIcon icon="schedule" />} />
      <div className="screen fade-in" style={{ paddingBottom: 24 }}>
        <div style={{ padding: '4px 20px 12px' }}>
          <div className="eyebrow">menú del día</div>
          <h1 style={{ margin: '4px 0 0', font: '900 26px/1.05 var(--rv-font)', letterSpacing: '-1px' }}>
            Hoy en la cafetería
          </h1>
          <div style={{ marginTop:6, color:'var(--rv-muted)', font:'500 12.5px var(--rv-font)' }}>
            Abierto 8:30 — 16:00 · Plaza de la Lealtad, 1
          </div>
        </div>
        <div className="cat-row">
          {cats.map(c => (
            <div key={c} className={'cat' + (c === cat ? ' active' : '')} onClick={() => setCat(c)}>{c}</div>
          ))}
        </div>
        <div className="col" style={{ marginTop: 14 }}>
          {items.map((it, i) => (
            <div key={i} className="menu-item">
              <div className="pic"><span className="material-symbols-rounded">{it.icon}</span></div>
              <div className="body">
                <div className="t">{it.t}</div>
                <div className="s">{it.s}</div>
              </div>
              <div className="price">{it.p}</div>
            </div>
          ))}
        </div>
      </div>
    </React.Fragment>
  );
}

/* ── Profile ────────────────────────────────────────────────────────── */
function ProfileScreen({ user, onLogout }) {
  return (
    <React.Fragment>
      <AppBar title="Perfil" actions={<GhostIcon icon="settings" />} />
      <div className="screen fade-in" style={{ paddingBottom: 24 }}>
        <div style={{ padding: '12px 20px', display:'flex', alignItems:'center', gap: 14 }}>
          <div style={{
            width:64, height:64, borderRadius:'50%',
            background: 'var(--rv-grad)', color:'#fff',
            display:'flex', alignItems:'center', justifyContent:'center',
            font: '800 24px var(--rv-font)', boxShadow: 'var(--rv-shadow-button)'
          }}>{user.name.split(' ').map(n => n[0]).slice(0,2).join('')}</div>
          <div style={{ flex:1 }}>
            <div style={{ font:'800 18px var(--rv-font)' }}>{user.name}</div>
            <div style={{ font:'500 12.5px var(--rv-font)', color:'var(--rv-muted)' }}>{user.role} · {user.email}</div>
          </div>
        </div>

        <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:10, padding:'8px 20px 4px' }}>
          <div className="card" style={{ padding:14 }}>
            <div className="eyebrow">tokens</div>
            <div style={{ font:'900 26px var(--rv-font)', color:'var(--rv-accent)' }}>{user.tokens}</div>
            <div style={{ font:'500 11.5px var(--rv-font)', color:'var(--rv-muted)' }}>Renueva el lunes</div>
          </div>
          <div className="card" style={{ padding:14 }}>
            <div className="eyebrow">reservas</div>
            <div style={{ font:'900 26px var(--rv-font)' }}>14</div>
            <div style={{ font:'500 11.5px var(--rv-font)', color:'var(--rv-muted)' }}>Este trimestre</div>
          </div>
        </div>

        <SectionTitle title="Ajustes" />
        <div className="col">
          <Tile icon="notifications_active" title="Notificaciones" subtitle="Push y por correo" />
          <Tile icon="dark_mode"            title="Tema oscuro"     subtitle="Sigue la configuración del sistema" />
          <Tile icon="language"             title="Idioma"          subtitle="Español" />
          <Tile icon="bug_report"           title="Reportar incidencia" subtitle="Avisa al equipo del centro" />
          <Tile icon="info"                 title="Acerca de Reservives" subtitle="Versión 1.0" />
        </div>

        <div style={{ padding: '20px 20px 0' }}>
          <button className="btn-outline" onClick={onLogout} style={{ color: 'var(--rv-error)', borderColor: 'rgba(255,93,115,.30)' }}>
            <span className="material-symbols-rounded" style={{ fontSize: 18 }}>logout</span>
            Cerrar sesión
          </button>
        </div>
      </div>
    </React.Fragment>
  );
}

/* ── Asistente IA (simple chat shell) ───────────────────────────────── */
function AsistenteScreen() {
  return (
    <React.Fragment>
      <AppBar title="Asistente IA" actions={<GhostIcon icon="restart_alt" />} />
      <div className="screen fade-in" style={{ display:'flex', flexDirection:'column', padding: '12px 20px 12px' }}>
        <div style={{ alignSelf:'flex-start', maxWidth:'80%', background:'#fff', borderRadius:'18px 18px 18px 6px', padding:'12px 14px', boxShadow:'var(--rv-shadow-soft)', font:'400 13.5px/1.5 var(--rv-font)' }}>
          ¡Hola! Soy el asistente del IES Luis Vives. Puedo ayudarte con horarios, reservas, menú y más. ¿En qué te ayudo?
        </div>
        <div style={{ alignSelf:'flex-end', maxWidth:'80%', marginTop:12, background:'var(--rv-grad)', color:'#fff', borderRadius:'18px 18px 6px 18px', padding:'12px 14px', font:'500 13.5px/1.5 var(--rv-font)', boxShadow:'var(--rv-shadow-button)' }}>
          ¿Qué hay hoy en la cafetería?
        </div>
        <div style={{ alignSelf:'flex-start', maxWidth:'85%', marginTop:12, background:'#fff', borderRadius:'18px 18px 18px 6px', padding:'12px 14px', boxShadow:'var(--rv-shadow-soft)', font:'400 13.5px/1.5 var(--rv-font)' }}>
          Hoy hay <b>bocadillo de jamón</b> (2,80 €), <b>tortilla de patata</b> (1,80 €) y <b>empanada gallega</b> (2,40 €), entre otros. ¿Quieres que reserve algo?
        </div>
        <div style={{ marginTop:'auto', display:'flex', gap:8, alignItems:'center', background:'#fff', borderRadius:16, padding:'10px 12px', boxShadow:'var(--rv-shadow-soft)' }}>
          <input className="field" placeholder="Pregúntame algo…" style={{ background:'transparent', border:'none', padding:0 }} />
          <button className="btn-primary" style={{ width:44, height:44, padding:0, borderRadius:'50%' }}>
            <span className="material-symbols-rounded">arrow_upward</span>
          </button>
        </div>
      </div>
    </React.Fragment>
  );
}

Object.assign(window, {
  LoginScreen, HomeScreen, ReservasScreen, SpaceDetailScreen, CafeteriaScreen, ProfileScreen, AsistenteScreen
});
