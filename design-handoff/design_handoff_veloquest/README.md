# Handoff: Velocity — «Велоквест» (gamified cycling-map app, iOS)

## Overview
Velocity is a map app for urban cyclists in Moscow: it shows the city's cycling
infrastructure, bike POIs and community problem-reports on one map, builds A→B bike
routes, and lets the community keep the data fresh through moderated edits — rewarded
with points. The full product spec is in `spec.en.md` (copied into this bundle).

This handoff covers the **«Велоквест» (VeloQuest) design direction** — the chosen,
heavily gamified take. Every core product flow is wrapped in a bright, "it's a game"
layer: levels & XP, daily quests, streaks, badges/titles, a Duolingo-style league,
a battle-pass season, a district "conquest" map, a reacting mascot, and a full-screen
level-up celebration. Two alternative directions were also explored and are included
for reference only (see **Files**): `VeloClassic` (native-HIG, tab bar) and
`VeloFlow` (map-first, gesture sheet, dark).

Target platform (from the spec): **iOS 17+, Swift 5.10+, SwiftUI, MVVM**, map via
**MapLibre Native**. Localization RU/EN (String Catalogs), light + dark themes.

## About the Design Files
The files in this bundle are **design references authored in HTML** (streaming
"Design Components"). They are working, clickable prototypes that show the intended
**look, layout, motion and behavior** — they are **not** production code to port
line-for-line. HTML/CSS values (SVG map illustration, inline styles, JS state machine)
exist only to demonstrate the design.

**Your task:** recreate these designs in the project's real environment — **SwiftUI**
(per the spec) — using its own components, navigation, `Color`/`Font` tokens, MapLibre
layers, HealthKit, and networking. Treat the HTML as the source of truth for visuals
and interaction, not for architecture. The real map is MapLibre with a custom style +
GeoJSON layers from the backend (spec §7); the prototype fakes it with a stylized SVG.

To view a prototype: open `VeloQuest.dc.html` in a browser (keep `support.js`
alongside — it is the runtime). `Velocity.dc.html` shows all three directions
side-by-side on a pannable canvas.

## Fidelity
**High-fidelity.** Final colors, typography, spacing, radii, shadows, motion and copy
(RU + EN) are all specified and should be reproduced faithfully. The visual system is
Apple-HIG-grounded (system font, iOS system colors) with an added vibrant gamification
palette. Where the prototype fakes data (leaderboards, %s, dates) treat it as
placeholder content wired to the real API described in `spec.en.md`.

---

## Global chrome & shell

- **Device canvas:** 390 × 844 pt (iPhone 14/15 logical size). Dynamic-Island notch
  pill at top; a simulated status bar (9:41, signal/wifi/battery) — replace with the
  real system status bar.
- **Tab bar (VeloQuest):** 5 items, height ~83pt, `--card` background, hairline top
  border `--sep`. Order: **Домой / Карта / ➕ / Лига / Профиль** (Home / Map / + /
  League / Profile). Center is a raised primary "+" button (52×34, radius 12,
  `--tint` fill, white plus, shadow `0 6px 16px rgba(0,90,220,.4)`). Active item =
  `--tint`, inactive = `--tx3`; label 10px/600; icon 24px line (1.9 stroke).
- **"+" action sheet:** iOS action sheet from bottom — «Сообщить о проблеме» (red),
  «Предложить дорожку» (green), «Добавить точку (POI)» (tint), + Cancel. Rows 57pt,
  radius 15, `--card2`, backdrop `rgba(0,0,0,.32)`, entry `vSheet .28s`.
- **Toasts:** top, 16pt inset, colored pill, white text 14/600, icon left, auto-dismiss
  2.6s, entry `vToast .3s`.
- **"+XP" fly-ups:** green pill that floats up & fades (`vFly 1.1s`) on rewards.
- **Confetti:** 26 pieces radiating from ~38% height on a reward (`vConf` .9–1.4s).

---

## Screens / Views

### 1. Onboarding (3 slides)
- **Purpose:** value props before mandatory sign-in.
- **Layout:** full-screen `--bg`; top-right "Пропустить"/"Skip"; centered illustration
  (230×150 rounded card w/ colored route strokes) + title (27px/800, -.6 letter-spacing)
  + description (16px/`--tx2`, line-height 1.45); paged dots at bottom (active dot 18px
  wide `--tint`, others 7px `--tx3`); primary button (52pt, radius 14, `--tint`, white
  17/600). Slide change animates `vPop .4s`.
- **Copy:** (1) "Вся веломосква на одной карте" (2) "Маршрут от А до Б для велосипеда"
  (3) "Держим карту свежей вместе". Last button = "Поехали"/"Let's ride".

### 2. Sign-in
- **Purpose:** mandatory auth (spec ACC-2). App icon (92×92, radius 23,
  `linear-gradient(160deg,#0A84FF,#0056D6)`, bobbing `vBob 3s`), wordmark "Velocity"
  30/800, subtitle. Two buttons (52pt/radius14): **Sign in with Apple** (`--appleBg`
  black / white in dark) and **Google** (`--card` + `--sep` border). Footnote 12/`--tx3`.
- Real impl: Sign in with Apple + Google Sign-In → exchange for backend JWT.

### 3. Home / Quest Hub  ← primary landing (tab «Домой»)
- **Purpose:** the game dashboard.
- **Layout** (scroll, padding 58/16/100):
  - **Header:** greeting "Привет, Аня!" (27/800) + subtitle; top-right **streak chip**
    `linear-gradient(135deg,#FF9F0A,#FF375F)`, white, flame glyph + "12", radius 15.
  - **Hero level card:** radius 24, `linear-gradient(140deg,#6C5CE7,#A742F5 52%,#FF5CA8)`,
    white text, decorative translucent circles. Left: **level ring** 84×84 (track
    `rgba(255,255,255,.25)` 8px, progress white 8px, rounded, dashoffset ≈ 26/50),
    center "LVL / {level}" (30/800). Right: title "Хранитель Хамовников" (12/700),
    "{XP} XP" (28/800), **XP progress bar** (9px, white fill on `rgba(255,255,255,.25)`,
    animates width 1s), "60 XP до ур. {next}".
  - **Quick actions:** 3 tiles (78pt, radius 17, `color-mix(color 13%, --card)`): Маршрут
    (tint), Репорт (red), Дорожка (green) — 36px round icon chip + 12/700 label.
  - **Задания дня (daily quests):** section head 20/800 + "обновятся через 6 ч".
    3 quest cards (radius 17, `--card`): 46px round-rect colored icon, title 15/700,
    reward "+50 XP" (13/800 colored), progress bar (7px) + "n/m" count. A completed-but-
    unclaimed quest gets a colored ring/glow (`0 0 0 2px color`) and a **"Забрать"/Claim**
    button (bobbing `vBob`); claimed shows a green check. Claim → confetti + "+XP" + toast.
  - **Значки (badges):** head 20/800; row of 4 badges (60px circles, earned =
    `linear-gradient` + colored shadow, locked = `--card2` + lock icon).
  - **Рейтинг района (leaderboard peek):** head + "Всё" link (→ League); card with top-3
    rows: rank medal (26px: gold #FFC400 / silver #B8BEC9 / bronze — for you row an
    orange chip), 34px avatar, name, "{XP} XP"; the "Вы"/You row tinted
    `color-mix(--tint 10%)`.

### 4. Map  (tab «Карта»)
- **Purpose:** the live infrastructure map (MapLibre in production).
- **Layers rendered on the map:**
  - **Infrastructure segments** color-coded by type: protected path `--c-prot #2FA84F`
    (solid), painted lane `--c-lane #FF9500` (solid), shared-with-peds `--c-shared`
    (dash 11 9), MTB trail `--c-mtb #AF52DE` (dash 3 10), other `--c-other #30B0C7`.
    Stroke 5px round. Tap → segment card.
  - **POIs** as 11px colored dots w/ white ring: workshop=orange, parking=tint,
    fountain=teal, rental=green. Tap → POI card.
  - **Reports** as colored warning triangles (red pothole/hazard, orange closure). Tap →
    report card.
  - **"Me"** dot: tint 7.5px + white ring + pulsing halo (`vPulse 2.6s`).
  - **© OpenStreetMap contributors** attribution baked into the map (mandatory, spec SET-2).
- **Game overlays (VeloQuest-specific):**
  - **Fog of war:** translucent `rgba(104,106,130,.34)` blobs over "uncharted" corners
    with white "?" glyphs — cleared as the district gets mapped.
  - **District-conquest pill** (bottom-left, radius 15, `--card`): flag icon + "Хамовники"
    (13.5/800) + "68%" (green), green→teal progress bar, "3 дорожки до захвата района".
- **Chrome:** top search pill ("Поиск места или адреса"), top-right avatar (→ Profile),
  right toolbar (layers + recenter, 46px round `--card` w/ `--shadow`).
- **Cards** (bottom sheets, radius 22 top, grabber, `vSheet .3s`):
  - **Segment card:** color swatch + type name (20/800); rows Покрытие / Состояние /
    Источник (OSM | Данные сообщества) / Обновлено; primary "Сообщить о проблеме" (red).
  - **POI card:** 52px gradient icon + name + type; photo placeholder; Адрес / status rows;
    "Маршрут сюда" (tint) + favorite star toggle.
  - **Report card:** category icon + name + reporter/expiry; comment; up-to-3 photo thumbs;
    confirmations count; **"Подтвердить"** (green, +2 XP) / **"Уже нет"**.
  - **Layers sheet:** toggles (infrastructure / MTB / POI / reports) as iOS switches
    (51×31, on = green, knob 27px) + a legend of the 5 infra colors.
  - **Search sheet:** full-screen; search field + "Недавнее" recents list.

### 5. Route  (from Home quick action or POI card)
- A→B builder: From ("Моё местоположение", green dot) / To (red pin) card with swap;
  profile segmented control **Город / MTB** (icon + label, selected = `--card` +
  `--shadowS`); "Построить маршрут" (tint). Built state (animates `vPop`): 3 stat tiles
  (км / мин / м набора), infra-% bar (green→green gradient), **elevation area chart**
  (svg, tint fill gradient + line), "Сохранить в избранное" + "Изменить". Empty state:
  route illustration + hint copy.

### 6. Report flow (full-screen)
- Nav bar (Cancel / "Проблема на карте"); category grid 3-col of 5 (Яма / Стекло /
  Перекрытие / Опасность / Другое) — 82pt tiles, selected = 2px colored border; comment
  field (placeholder, blinking caret); "Фото · до 3" thumbs + dashed add tile; location
  card ("по вашей геопозиции"). Sticky bottom "Отправить" (red). Submit → confetti +
  "+10 после модерации" toast.

### 7. Draw-a-lane flow (hero interaction) → Level-up
- **Draw mode:** map with instruction banner (pencil icon + "Новая дорожка" + hint that
  changes at ≥2 points) and a bottom toolbar: Undo / Clear / live "{n} точек" / "Далее"
  (enabled at ≥2, opacity .4 when disabled). **Tap the map to add points**; **drag point
  handles** (7px white/green circles) to adjust. Live dashed green polyline.
- **Details sheet:** back + "Новая дорожка"; lane-type list (5 rows, colored line sample,
  selected = colored border + check); surface pills (Асфальт/Грунт/Гравий/Неизвестно);
  review note; "На модерацию" (green). Submit →
- **Level-up celebration** (full-screen, z-top): background
  `radial-gradient(circle at 50% 40%,#3b2a86,#201248,#0e0824)`; rotating conic rays
  (`vSpin 22s`); twinkling "✦" stars (`vStar`); floating **mascot** (`vFloat 3s`); gold
  "УРОВЕНЬ ПОВЫШЕН!" (14/800, 3px tracking, `#FFD34D`); **ring** 172px animating to the
  new level (`vRingGrow 1.1s`, gradient `#FFD34D→#FF7AC8`), center "LVL / 8" (60/900,
  `vBeat`); title; **badge-unlock card** ("Новый значок · Картограф", green badge);
  white "Далее" button. Entry `vPopBig .55s` spring. On dismiss the app's level increments.

### 8. Profile — «Игровой паспорт» (tab «Профиль»)  ← hero screen
- **Header row:** "Профиль" (30/800) + settings gear (→ Settings).
- **Passport hero card:** radius 24,
  `linear-gradient(150deg,#5B4BE0,#9A3FE8 52%,#E24FA0)`, animated **shine sweep**
  (`vShine 4.5s`). Centered: 100px avatar with white progress ring + inner
  `linear-gradient(150deg,#FF9500,#FF375F)` "А", **"LVL 7"** gold chip; name "Аня В."
  (23/800); title pill "👑 Хранитель Хамовников" (crown svg + 13/700); 3-stat row
  (XP / #3 ранг / 12 серия) separated by faint dividers.
- **Season / battle-pass card:** "Сезон 3 · Весна" + "осталось 12 дней" + "Тир 3 / 8"
  pill; horizontal tier track: 40px nodes (done = green + icon, current = purple +
  ring + shadow, locked = `--card2` grey) with connector lines colored up to current;
  reward icons (star/bike/shield/gift/trophy/star), labels Т1…Т6.
- **Stats row:** 4 cards (184 км / 8 правки / 21 сообщения / 46 подтверждения), value
  21/800 colored.
- **Streak card:** "Серия · 12" + "рекорд 18" flame; 7 day-circles (34px), done = orange
  + white flame, today = 2.5px `--tx` outline, future = `--card2`.
- **Badges grid:** head + "{earned}/8"; 4-col grid, each badge square (radius 18, earned =
  `linear-gradient(150deg,color,darker)` + colored shadow, locked = `--card2` + lock);
  label 10/600. **Tap → badge-detail sheet** (bottom, radius 24): 98px badge (spring
  `vPopBig`), name 23/800, description, status row ("Получен" / "Прогресс" + "62 / 100").
- **Account lists** below: Избранное / Мои сообщения / Мои правки (with counts) and
  Поездки / Настройки — standard grouped rows w/ chevrons.

### 9. League  (tab «Лига»)  ← hero screen
- Header "Лига" + season timer chip ("⏱ 5 дней").
- **League emblem card:** `linear-gradient(150deg,#FFB020,#FF7A00)`, shine sweep; white
  shield+star emblem (72px); "Золотая лига" (23/800); "Топ 5 проходят в Платиновую лигу".
- **Tier ladder:** Бронза / Серебро / Золото (current, filled `#FFC400`, scaled 1.06) /
  Платина / Алмаз (locked grey) pill row.
- **Promotion zone:** green "↑ ЗОНА ПОВЫШЕНИЯ" label; card of ranks 1–5 (rank medal
  colored for top-3, 34px avatar, name, "{XP} XP"); the **"Вы"** row tinted
  `color-mix(--tint 13%)`, bold. Second card ranks 6–9 with the bottom (demotion) rows
  tinted `color-mix(--red 7%)`; red "↓ Ниже — зона вылета" label.

### 10. Rides (Apple Health)  — from Profile
- Permission state: red HealthKit heart tile, "Импорт из Apple Health", rationale copy,
  "Только чтение · Локально" chip, "Разрешить доступ к Health". Granted state: green
  "Хранится только на устройстве" banner + ride cards (title/date, mini track svg,
  stats km / time / avg / avg-HR). Data is **device-local only** (spec HLT-4).

### 11. Settings / About / Rules  — from Profile gear
- Settings: Язык segmented (Русский / English), Оформление segmented (Светлое / Тёмное),
  list (О приложении / Политика конфиденциальности / Правила сообщества), red "Удалить
  аккаунт" (spec ACC-5), version + OSM/ODbL footer. About: app icon, tagline, OSM
  attribution card, advisory-routes disclaimer. Rules: numbered do/don't cards.

---

## Interactions & Behavior
- **Navigation:** tab bar switches Home/Map/League/Profile; "+" opens action sheet;
  sub-screens (Route, Report, Draw, Rides, Settings, About, Rules) are pushed
  full-screens or bottom sheets with back/cancel.
- **Draw:** tap map = add vertex; drag vertex handle = move; Undo/Clear; ≥2 pts enables
  Далее. On submit → **level-up celebration** then toast.
- **Quest claim / report confirm / lane submit:** always trigger a reward moment
  (confetti + "+XP" fly-up + toast); a lane submit crosses a level → full level-up.
- **Animations (keyframes, reproduce as SwiftUI animations/springs):**
  `vPop` .4s scale-in · `vPopBig` .55s spring (0.3→1.14→1) · `vSheet` .3s slide-up ·
  `vFade` .2s · `vToast` .3s · `vFly` 1.1s float-up-fade · `vConf` .9–1.4s confetti ·
  `vDraw`/`vRingGrow` 1.1s stroke-dashoffset · `vSpin` 22s rays · `vBob` 3s idle bob ·
  `vFloat` 3s mascot float · `vShine` 4.5s highlight sweep · `vStar` twinkle ·
  `vBeat` number pop · `vPulse` 2.6s location halo.
- **Theme:** system / light / dark (toggle in Settings). **Language:** RU default, EN
  toggle — 100% of strings localized incl. categories/statuses (spec §11).
- **Accessibility:** Dynamic Type, VoiceOver labels, ≥44pt hit targets, legend contrast
  in both themes (spec §11).

## State Management (SwiftUI / MVVM suggestion)
- **Auth:** signed-out → onboarding/auth; signed-in → app. JWT in Keychain.
- **Gamification (server-owned, spec PTS):** `points/XP`, `level`, `streak`, per-quest
  progress + claimed flag, badges (earned + progress), league (rank list, promotion/
  demotion, season timer), season/battle-pass tier. Points granted **only after
  moderation**: edit +50, POI +20, report +10 (after validation), confirmation +2;
  daily grant limits; no points for rejected (PTS-1/PTS-3).
- **Map:** enabled layers (infra/MTB/POI/reports); viewport bbox → GeoJSON fetch + cache;
  selection (segment/POI/report); district-progress %.
- **Draw:** `{active, points:[LngLat], selectedType, surface, photos}`; step draw→details.
- **Report:** `{category, comment, photos, geo}`.
- **Route:** `{from, to, profile:.city|.mtb, built, distance, time, ascent, infraPct,
  elevation[]}`; favorites.
- **Rides:** HealthKit workouts imported on demand, **stored locally only**.
- **Level-up:** transient flag raised when XP crosses a threshold; blocks until dismissed.

## Design Tokens

**Light (default) — `:root`**
- bg `#EFEFF4` · card `#FFFFFF` · card2 `#F7F7FA` · sep `rgba(60,60,67,.13)` · hair
  `rgba(60,60,67,.29)`
- text `#000000` · text2 `rgba(60,60,67,.6)` · text3 `rgba(60,60,67,.32)`
- tint `#007AFF` · green `#34C759` · red `#FF3B30` · orange `#FF9500` · purple `#AF52DE`
  · yellow `#FFCC00` · teal `#30B0C7`
- infra: protected `#2FA84F` · lane `#FF9500` · shared `#9AA0A6` · mtb `#AF52DE` ·
  other `#30B0C7`
- map: land `#E9E7DF` · park `#D3E5C4` · water `#AAD3F2` · road `#FFFFFF` · road-edge
  `#E2E0D6`
- shadow `0 8px 26px rgba(0,0,0,.16)` · shadowS `0 2px 10px rgba(0,0,0,.10)`

**Dark — `[data-theme=dark]`**
- bg `#000000` · card `#1C1C1E` · card2 `#2C2C2E` · sep `rgba(84,84,88,.4)` · text `#FFFFFF`
  · text2 `rgba(235,235,245,.62)` · text3 `rgba(235,235,245,.32)`
- tint `#0A84FF` · green `#30D158` · red `#FF453A` · orange `#FF9F0A` · purple `#BF5AF2`
  · teal `#40C8E0` · infra protected `#32D74B`, mtb `#BF5AF2`
- map: land `#20242B` · park `#1F3324` · water `#123047` · road `#3A3F47` · road-edge `#2A2E35`
- shadow `0 8px 26px rgba(0,0,0,.5)` · shadowS `0 2px 10px rgba(0,0,0,.4)`

**Gamification gradients & accents (both themes)**
- Hub level card `linear-gradient(140deg,#6C5CE7,#A742F5 52%,#FF5CA8)`
- Passport hero `linear-gradient(150deg,#5B4BE0,#9A3FE8 52%,#E24FA0)`
- Level-up bg `radial-gradient(circle at 50% 40%,#3b2a86,#201248,#0e0824)`
- Avatar `linear-gradient(150deg,#FF9500,#FF375F)` · Streak chip
  `linear-gradient(135deg,#FF9F0A,#FF375F)` · League gold
  `linear-gradient(150deg,#FFB020,#FF7A00)`
- Gold `#FFD34D` · pink `#FF7AC8` · mascot helmet `#7B5CFF`
- League tiers: bronze `#CD7F32` · silver `#B8BEC9` · gold `#FFC400` · platinum `#5AC8FA`
  · diamond `#AF52DE`

**Typography** — system font (`-apple-system` / **SF Pro**; use `.rounded` design for
the game numerals if desired). Weights 500/600/700/800/900. Scale seen: large titles
30–32 / 800 (letter-spacing −.7…−.8); hero numerals 28–64 / 800–900; section heads
19–20 / 800; body 15–16; secondary 13–14 / `text2`; captions/labels 10–12; overline
labels uppercase 12.5 / 700 with +.4 tracking.

**Radii** — buttons/inputs 13–15 · cards 14–18 · hero/sheets 22–24 · pills 10–16 ·
switches/dots fully round. **Spacing** — screen inset 16; card padding 14–22; gaps 8–12.

## Assets
- **No bitmap assets.** All icons are inline single-color SVG line icons (24px grid,
  ~1.9 stroke) — replace with **SF Symbols** in SwiftUI (map, bicycle, trophy, flame,
  star, shield, gift, checkmark, pencil, etc.).
- **Mascot** = a simple original geometric SVG character (purple bike-helmet buddy with
  eyes/smile; a cheering arms-up variant for level-up). Redraw as a vector asset or SF
  Symbol composition; it animates with float/bob.
- **Map** = stylized SVG stand-in only; production uses **MapLibre Native** with a custom
  style (OpenFreeMap base tiles) + our GeoJSON layers (spec §7/§8).
- Photo areas are gradient placeholders → user/community photos via presigned S3 (spec §7).
- **OpenStreetMap © + ODbL attribution is mandatory** on the map and in About (spec §12).

## Files (in this bundle)
- `VeloQuest.dc.html` — **the chosen design (this handoff)**. Open in a browser.
- `VeloClassic.dc.html`, `VeloFlow.dc.html` — the two alternative directions (reference).
- `Velocity.dc.html` — canvas presenting all three side-by-side.
- `support.js` — runtime required to open any `.dc.html` (keep alongside).
- `spec.en.md` — the product/MVP specification (scope, data model, API, privacy, roadmap).

> The `.dc.html` files are inline-styled HTML prototypes; there is no separate CSS file —
> all tokens above are declared as CSS custom properties in the `<style>` block at the top
> of each file, and everything else is inline. Recreate in SwiftUI, do not port the HTML.
