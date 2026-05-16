---
name: reservives-design
description: Use this skill to generate well-branded interfaces and assets for Reservives — the IES Luis Vives reservations app — either for production or throwaway prototypes/mocks/etc. Contains essential design guidelines, colors, type, fonts, assets, and UI kit components for prototyping.
user-invocable: true
---

Read the README.md file within this skill, and explore the other available files.

If creating visual artifacts (slides, mocks, throwaway prototypes, etc), copy assets out and create static HTML files for the user to view. If working on production code, you can copy assets and read the rules here to become an expert in designing with this brand.

If the user invokes this skill without any other guidance, ask them what they want to build or design, ask some questions, and act as an expert designer who outputs HTML artifacts _or_ production code, depending on the need.

Key files:
- `README.md` — brand context, content fundamentals, visual foundations, iconography.
- `colors_and_type.css` — design tokens (CSS custom properties), Inter type scale.
- `assets/` — logos and bitmap brand icons (Microsoft, LinkedIn, X, YouTube).
- `preview/` — small spec cards (colors, type, radii, shadows, components).
- `ui_kits/reservives_app/` — interactive Flutter-app recreation in React.

Brand quick reference:
- Primary `#D23F7A` (rose), Accent `#B53F7A` (fuchsia/magenta).
- Backgrounds: `#F6F7FB` light / `#090B10` dark. Cards `#FFFFFF` / `#151A24`.
- Type: **Inter** only — heavy negative letter-spacing on display sizes,
  uppercase eyebrows at +1.0 letter-spacing.
- Radii: `10 / 14 / 20 / 32 / pill (999)`.
- Iconography: Material Symbols **Rounded**, outline weight, monochrome.
  No emoji in product UI.
- Voice: Spanish, `tú` form, sentence-case, warm but respectful, no emoji.

Always copy assets and tokens — never invent new brand elements.
