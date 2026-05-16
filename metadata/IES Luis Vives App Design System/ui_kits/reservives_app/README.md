# Reservives App — UI kit

Interactive recreation of the **Reservives** Flutter app (mobile + web)
shipping under `vms.iesluisvives.org`. Modelled on
`gonnzaxx/RESERVIVES` (`frontend/lib/`).

## What's covered

- **Login** (Microsoft EntraID + guest) with the animated background blobs
  and frosted-glass login card.
- **Home** — greeting + tokens, polls banner (the brand gradient), next
  bookings, announcements.
- **Reservas** — searchable list of spaces with category chips.
- **Space detail** — day picker (7 days), slot grid, sticky footer CTA.
- **Cafetería** — daily menu by category.
- **Asistente IA** — chat shell.
- **Perfil** — avatar, KPIs, settings, logout confirm dialog.

## Files

```
ui_kits/reservives_app/
  index.html      ← bootstraps the app, hosts navigation state
  theme.css       ← tokens + every primitive used in the kit
  components.jsx  ← AppBar, BottomBar, Tile, ActivityRow, PollsBanner,
                    Toast, ConfirmDialog, EmptyState, GhostIcon, …
  screens.jsx     ← LoginScreen, HomeScreen, ReservasScreen,
                    SpaceDetailScreen, CafeteriaScreen, ProfileScreen,
                    AsistenteScreen
```

## Notes

- The Flutter app uses Material **rounded** icons; this kit substitutes
  Google's free **Material Symbols Rounded** via the icon font CDN.
- The Flutter app constrains its web layout to `~700px` and runs a phone
  shell; the kit mirrors that with a 440 × 900 px shell on a hero gradient.
- Backend / auth are mocked. Sign-in resolves after a fake delay.
