# Reservives — IES Luis Vives App · Design System

> **Plataforma integral de gestión de reservas y recursos** para el IES Luis Vives.
> Login con Microsoft EntraID, sistema de tokens, reservas de aulas y servicios,
> tablón, cafetería, encuestas, incidencias y un asistente IA.

This design system documents the visual identity, foundations, components and
copy guidelines lifted directly from the Reservives codebase, so future work
can be created against the same brand.

---

## Sources

The system was reconstructed from the public GitHub repository **`gonnzaxx/RESERVIVES`** (`main` branch) — specifically:

- `frontend/lib/config/app_theme.dart` — `AppColors`, `AppRadii`, `AppShadows`, `lightTheme`, `darkTheme`.
- `frontend/lib/widgets/design_system.dart` — `Rv*` Flutter widgets (cards, buttons, badges, search, alerts, empty/error states).
- `frontend/lib/screens/login_screen.dart`, `home/home_screen.dart` — applied patterns.
- `frontend/assets/{icons,images}/` — bitmap logos and social icons (imported into `assets/`).
- `metadata/*.png` — original logo and architecture diagram.
- The repo's own `README.md` for product/feature context.

The user did not attach a Figma file. There is also a private companion repo `gonnzaxx/RESERVIVES-DESARROLLO` (not imported here).

---

## Product context

Reservives is a **Flutter (Web + iOS + Android)** application backed by a
Python/FastAPI service and PostgreSQL. There is **one product surface** — the
end-user app (used both as a phone app and as an in-browser web app at
`vms.iesluisvives.org:2121`). The same Flutter codebase serves an admin
back-office at the routes under `/admin`.

Key flows:

- **Login** with Microsoft EntraID, plus a guest mode with restricted access.
- **Home / Dashboard**: greeting, polls banner, the user's next 5 bookings, the
  announcements bulletin board.
- **Reservas**: pick a space (classroom, sports court…), see a 14-day calendar,
  book a slot, optionally as a recurring booking pending admin approval.
- **Servicios**: book department services (e.g. peluquería) on an
  approval flow.
- **Cafetería**: digital menu by category.
- **Encuestas**: single-vote polls.
- **Incidencias**: report problems, attach an image.
- **Asistente IA** (Gemini chat with rate limiting).
- **Backoffice** for admin / jefatura: KPIs, history, users, tokens, slots,
  spaces, services, cafeteria, surveys, incidents.

The internal currency is **tokens**: each reservation deducts tokens; the
amount and refill rules are configurable per role.

---

## Index — files in this project

```
.
├── README.md                  ← you are here
├── SKILL.md                   ← skill manifest (works with Claude Code)
├── colors_and_type.css        ← design tokens (vars) + type scale
├── fonts/                     ← (Inter is loaded from Google Fonts)
├── assets/                    ← logos & icons copied from the repo
│   ├── logo_luis_vives.png
│   ├── logo_luis_vives_oscuro.png
│   ├── microsoft_icon.png
│   ├── linkedin_icon.png
│   ├── x_icon.png
│   ├── youtube_icon.png
│   └── esquema_arquitectura.png
├── preview/                   ← cards rendered in the Design System tab
│   ├── colors-primary.html
│   ├── colors-neutrals-light.html
│   ├── colors-neutrals-dark.html
│   ├── colors-semantic.html
│   ├── colors-gradient.html
│   ├── type-scale.html
│   ├── type-eyebrow.html
│   ├── radii.html
│   ├── shadows.html
│   ├── spacing.html
│   ├── components-buttons.html
│   ├── components-badges.html
│   ├── components-search.html
│   ├── components-card.html
│   ├── components-activity-card.html
│   ├── components-empty-state.html
│   ├── components-toast.html
│   ├── components-switch-tile.html
│   ├── components-skeleton.html
│   ├── brand-logo.html
│   └── brand-icons.html
└── ui_kits/
    └── reservives_app/
        ├── README.md
        ├── index.html         ← interactive click-thru of the app
        ├── theme.css
        ├── components.jsx
        └── screens.jsx
```

---

## Visual foundations

### Colors

| Token | Light | Dark |
| --- | --- | --- |
| **Primary (rose)** | `#D23F7A` (`primaryBlue`*) | same — accents lighten to `#F4A1C0` |
| **Accent (purple)** | `#B53F7A` — used as `ColorScheme.primary` everywhere | lighter `#EC64B3` for borders/links |
| Background | `#F6F7FB` | `#090B10` |
| Surface | `#FFFFFF` | `#11141C` |
| Card | `#FFFFFF` | `#151A24` (and `#1C1C1E` in places) |
| Text | `#10131A` | `#F5F7FF` |
| Text muted | `#667085` | `#B0B9CD` |
| Divider | `#E6E8F0` | `#2E3747` |
| Success / Warning / Error | `#2EC48D` / `#FFB020` / `#FF5D73` |  |
| Blue / Purple (semantic) | `#3289EC` / `#AA1FFF` |  |

\* The variable names `primaryBlue`/`accentPurple` in the codebase are
historical — neither is actually blue or purple. The brand reads as **rose
+ fuchsia + magenta** with a deep navy/black dark mode.

The brand gradient `accentPurple → primaryBlue` (`#B53F7A → #D23F7A`) appears
on the polls banner and other emphasis surfaces.

### Type

- **Single family: Inter**, loaded via `google_fonts` in Flutter and via
  `fonts.googleapis.com` here. No serifs, no monospace.
- Heavy negative letter-spacing on display sizes (`-1.0` … `-0.4`).
- Headings shipped at weights **w700 / w800 / w900** for impact.
- Body at w400/w500. Eyebrows are **uppercase, 700, +1.0 letter-spacing**.

Scale (px / weight): 40/700, 32/700, 28/700, 22/600, 20/600, 17/600, 17/400,
15/400, 13/500.

### Radii

`s = 10px` (inputs) · `m = 14px` (buttons, default cards) · `l = 20px`
(dialogs, surface cards, sheets) · `xl = 32px`. Pills (`999px`) on badges.

### Shadows

Two-step elevation, both with offset-Y blur and **no spread**:

- **Soft** — `0 8px 24px rgba(16,19,26,.08)` (light) / `…rgba(0,0,0,.25)` (dark).
- **Deep** — `0 25px 40px rgba(.,.,.,.12) + 0 4px 10px rgba(.,.,.,.03)` (light); dark adds a tinted accent layer.
- **Button glow** — coloured shadow that matches the button background, e.g.
  `0 4px 12px rgba(181,63,122,.3)`.

### Backgrounds

- Solid surface most of the time.
- The login screen uses an **animated background**: two large, soft, blurred
  blobs (one rose, one purple) that drift on a `sin/cos` orbit, layered over a
  pale linear gradient (`#F9FAFF → #F2F4FF → #E9F0FF`), with the gradient stops
  themselves animating.
- The polls banner is the only dense gradient (`brandGradient`).

### Animation

- Easing is overwhelmingly `Curves.easeOutCubic`, with `easeOutBack` for
  popping-in icons.
- Durations: hover 200 ms, press scale 100 ms, page transitions
  ~300 ms (Cupertino-style on every platform).
- `flutter_animate` is used for fade-in + slide-y on first paint; the polls
  banner gets a delayed shimmer at 2 s.
- The empty-state circle has a **breathing** loop (3 s, reverse).

### Hover states

- **Cards**: scale to **1.02**, border becomes `primary @ 0.20-0.28`, shadow
  upgrades from soft → deep.
- **Notification bell / icon buttons**: background fades from `0.03 → 0.06`
  alpha, border alpha tightens.
- Cursor switches to pointer; `splashFactory: NoSplash` — Material ripple is
  disabled globally.

### Press states

- **Scale to 0.96–0.97** with `AnimatedScale` (100 ms).
- Primary button additionally lowers opacity to **0.6** when disabled.
- Most taps fire `HapticFeedback.lightImpact` or `selectionClick` on mobile.

### Borders

- Cards always carry a hairline `1.0–1.5px` border that thickens slightly on
  hover. Color is mostly transparent black/white over the surface.
- Inputs are **borderless filled** with a 1.5px focused border in `accent`.

### Transparency & blur

- The login card is a **frosted-glass panel**: `BackdropFilter(blur 16px) +
  rgba(white, .72)` (light) / `rgba(black, .40)` (dark), border at white .60 / white .10.
- App bar uses the same trick (alpha .9 surface).

### Imagery

- **Photographs are not used in the codebase**, except user avatars and
  user-uploaded images (announcements, incidents). The brand image is the
  **stylised letterform logo** (`logo_luis_vives.png`).
- Avatars fall back to **initials on a tinted accent background** (the `RvAvatar`
  pattern referenced in `_AvatarButton`).

### Layout rules

- App scrolls within a `ConstrainedBox(maxWidth: AppConstants.webMaxWidth)` so
  the "web" view becomes a centred phone-shaped column on desktop. Switch
  point: `width > 700`.
- Page padding: 20 px horizontal, 14–24 px vertical.
- Vertical rhythm uses the spacing scale (4/8/12/16/20/24/32/40 px).

### Iconography

See [ICONOGRAPHY](#iconography) below.

---

## Content fundamentals

### Voice & tone

The product copy is **Spanish (primary), English and French**. Tone is **warm,
direct, slightly informal but respectful** — addressing users with the **`tú`**
form ("Iniciar sesión", "¿No tienes cuenta?", "Reservar").

- **Sentence-case** everywhere — no all-caps for body or titles. Exception:
  *eyebrow* labels above page headers are uppercased visually via CSS
  (`text-transform: uppercase`), not in source strings.
- **No emoji** in product UI. The repo README ends with one decorative ❤️.
  Treat emoji as off-brand.
- Iconography (Material rounded icons) replaces emoji.
- Greeting line on Home is time-aware: "Buenos días" / "Buenas tardes" /
  "Buenas noches".
- Status pills use one short word: `Pendiente`, `Aprobada`, `Rechazada`,
  `Cancelada`.
- Empty states address the user with an action verb ("Reservar ahora", "Ver
  todas las reservas (n)").

### Copy examples (from the repo's localisation files)

- Header eyebrow on Home: `"buenos días"` (rendered uppercase).
- Login eyebrow: `"login.welcomeEyebrow"` →  *BIENVENIDO/A A*.
- Login title: *Reservives — IES Luis Vives*.
- Login primary CTA: *Iniciar sesión con Microsoft*.
- Login secondary: *Continuar sin cuenta*.
- Polls banner: *Tienes {n} encuestas activas*.
- Empty bookings: *Aún no tienes reservas esta semana.*
- Confirm dialog defaults: *Sí / No*.
- Toast verbs: success / warning / error / info — single icon + a short
  sentence ending with a period.

### Numerals & dates

- Dates are localised to the active locale (`DateFormat('EEE')`,
  `DateFormat('d MMM')`); the day-name / month abbrev are uppercased visually.
- Times use `HH:mm` (24-hour).

---

## Iconography

- **Primary set: Material Icons (rounded variants)** — `Icons.search_rounded`,
  `Icons.notifications_outlined`, `Icons.bolt_rounded`,
  `Icons.how_to_vote_rounded`, `Icons.event_busy_rounded`,
  `Icons.access_time_rounded`, `Icons.chevron_right_rounded`,
  `Icons.push_pin_rounded`, `Icons.cloud_off_rounded`, etc.
- All icons are **outline / rounded weight**, monochrome, sized 12-20 px in UI.
- Tinted by the surrounding context's `colorScheme.primary` (the rose accent)
  or muted text color.
- **PNG bitmap icons** are reserved for **brand-marks**: the Microsoft logo
  on the login button, and the social network icons (LinkedIn / X / YouTube)
  used in the footer/about screens. These are imported into `assets/` of this
  design system.
- **No icon font** is bundled — Material Icons are part of Flutter.
- **No emoji** in product UI.
- For the HTML mocks here the closest CDN substitute for Material Rounded is
  **[Material Symbols Rounded via Google Fonts](https://fonts.google.com/icons)**
  (`<link href="https://fonts.googleapis.com/icon?family=Material+Symbols+Rounded">`),
  which we use in the UI kit.

> ⚠️ **Substitution flagged**: the codebase uses Flutter's bundled
> `Icons.*_rounded` set; the HTML mocks substitute Google's free
> *Material Symbols Rounded*. They are visually equivalent for the rounded
> variants but the icon names differ slightly (`how_to_vote_rounded` →
> `how_to_vote`).
