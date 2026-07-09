# Velocity — App Icon / Logo generation prompt

Grounded in the VeloQuest design handoff (the in-app `AppIconMark`): a blue gradient
rounded-square icon with a clean white bicycle/"V" mark. Use whichever section fits
your tool. Exact brand values are at the bottom.

---

## ⭐ Master prompt (primary icon — recommended)

> A modern iOS app icon for a cycling-map app called "Velocity". A single centered
> minimalist mark on a vivid blue gradient background. The mark is a clean, geometric
> white bicycle rendered in a bold, rounded, single-weight line style — two wheels and
> a frame that subtly forms the letter "V" (velocity), confident and friendly, not
> technical. Background is a smooth diagonal gradient from bright azure `#0A84FF` (top-left)
> to deep blue `#0056D6` (bottom-right), at roughly a 160° angle. Soft inner light from
> the top, a gentle glossy sheen, no harsh reflections. The white mark has crisp edges
> and a very subtle soft shadow for depth. Flat, premium, Apple-Human-Interface-Guidelines
> aesthetic — the kind of icon that looks at home on the iOS home screen next to Apple's
> own apps. Full-bleed square composition, the mark occupying ~55% of the frame, generous
> even margins, perfectly centered. Ultra-crisp, high detail, 1024×1024, sRGB.
>
> Negative: no text, no words, no letters other than the implied V, no rounded corners
> baked in (square canvas), no drop shadow outside the canvas, no photo-realism, no 3D
> bevel, no gradients other than blue, no clutter, no map pins, no roads, no border,
> no watermark, no transparency.

---

## Technical constraints (must-follow for iOS)

- **1024×1024 px**, square, **sRGB**, **no alpha/transparency** (opaque background).
- **Do NOT bake in rounded corners** — deliver a full-bleed square; iOS applies the
  superellipse mask itself. (If your tool always rounds, ask for "square canvas, sharp corners".)
- **No text** in the icon (app name shows under it on the home screen).
- Keep the mark inside a ~10% safe margin so nothing is clipped by the mask.
- One focal element, high contrast, readable at 48×48 px (test by shrinking).

---

## Variant A — Minimalist bike/V monogram (matches the current app)
> Centered white geometric bicycle line-mark on a `#0A84FF`→`#0056D6` diagonal blue
> gradient; the frame reads as a soft "V". Bold rounded strokes, flat, glossy-but-subtle,
> premium iOS icon, 1024×1024, no text, square full-bleed.

## Variant B — Gamified helmet mascot (matches VeloQuest's mascot)
> Playful iOS app icon: an original geometric mascot — a friendly purple bike-helmet
> character with big round eyes and a small smile, head-and-shoulders, centered — on a
> vivid blue gradient (`#0A84FF`→`#0056D6`). Helmet in purple `#7B5CFF` with a white rim,
> face in soft lavender `#F3F0FF`. Rounded, chunky, sticker-like, cheerful, high-quality
> mobile-game icon style. Soft top light, subtle sheen. 1024×1024, no text, square full-bleed,
> mark ~60% of frame. Negative: no realism, no 3D bevel, no text, no border.

## Variant C — "V + route" mark
> Minimalist white glyph on blue gradient: a bold letter "V" whose right stroke turns into
> a cycling route line with two small node dots (a start dot and a location pin end),
> suggesting A→B navigation. Clean, geometric, single weight. Premium flat iOS icon,
> `#0A84FF`→`#0056D6`, 1024×1024, no extra text, square full-bleed.

---

## Tool-specific one-liners

**Midjourney v6:**
`iOS app icon, minimalist white geometric bicycle forming a subtle "V", vivid blue gradient background #0A84FF to #0056D6 diagonal, bold rounded strokes, flat premium Apple HIG style, soft glossy sheen, centered, square full-bleed no rounded corners, no text --ar 1:1 --style raw --v 6`

**DALL·E 3 / GPT-image / ChatGPT:** paste the ⭐ Master prompt; add "flat vector look, square canvas with sharp corners, no transparency."

**Ideogram (good at clean shapes):** Master prompt + "flat vector, crisp edges, solid gradient, no texture."

**Stable Diffusion / SDXL:** Master prompt as positive; put the "Negative:" line in the negative field. Steps 30–40, CFG 6–7.

---

## If you want a true vector (SVG) instead of raster
Ask a code/vector tool: "Draw an iOS app icon as SVG, 1024×1024, `<rect>` full-bleed with
a linear gradient `#0A84FF`→`#0056D6` at 160°, and a centered white bicycle built from
`<path>`/`<circle>` strokes (stroke-linecap round, ~48px stroke on the 1024 grid) whose
frame reads as a 'V'. No text, no rounded corners on the rect." This matches the in-app
`AppIconMark` and stays crisp at any size.

---

## Brand values (single source of truth)
- Gradient: `linear-gradient(160deg, #0A84FF, #0056D6)`
- Mark color: white `#FFFFFF`
- Optional glow/shadow: `rgba(0,90,220,0.4)`
- Mascot (Variant B): helmet `#7B5CFF`, face `#F3F0FF`, eyes `#2A1E5C`
- Corner radius when *not* auto-masked (e.g. marketing): 22–23% of size (iOS squircle)
- After generating the 1024 master, export the standard set (or let Xcode's single-size
  App Icon handle it): 180, 120, 87, 80, 60, 58, 40 px, plus 1024 for the App Store.
```
