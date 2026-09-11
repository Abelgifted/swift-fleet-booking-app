# fleet_booking — project notes

Flutter fleet-booking app (Flutter 3.47.2 / Dart 3.13.2, Material 3,
Provider state management). Showcase project — the UI is deliberately
"premium / luxury brand" quality.

## Design system — `lib/config/premium_theme.dart`

Single source of truth: `abstract final class Lux`. **Always use it; never
hardcode colours, radii, spacing or shadows.**

- Palette: `ink` #0A1628 (deep navy), `gold` #C9A96E (champagne),
  `goldBright`/`goldDeep`, `ivory`/`cream`/`cardLight`, `dark*` surface set,
  `error`/`errorSoft`, `success`.
- Gradients: `goldGradient`, `inkGradient`, `heroOverlay`, `metallic`.
- Radii: `rSm` 12 / `rMd` 16 / `rLg` 24 / `rXl` 32. Spacing: `gap` 24.
- Shadows: `soft`, `goldGlow`, `floating`.
- Type helpers: `Lux.display/headline/title/body/caption/eyebrow(context, …)`.
- Themes: `Lux.light()`, `Lux.dark()`, `Lux.highContrast(ThemeData)`.
- Seat map: `Lux.seatAvailable/seatSelected/seatBooked/seatHeld/driverSeat`.

Fonts: Playfair Display (serif headings) + Inter (sans body) via `google_fonts`.

## Premium widget kit — `lib/widgets/`

`premium_card.dart` (`PremiumCard`, `GlassCard`, `Eyebrow`, `SectionHeader`,
`StatusBadge`, `GoldDivider`) · `premium_button.dart` (`PremiumButton`,
`GhostButton`) · `premium_input.dart` · `premium_loader.dart` (`ShimmerBox`,
`TripCardSkeleton`, `LuxuryLoader`) · `premium_image.dart` (`PremiumImage`,
`Imagery` — cached on native, `Image.network` on web) · `premium_fx.dart`
(`ConfettiBurst`, `AnimatedSuccessMark`, `AnimatedCounter`) ·
`premium_bottom_sheet.dart` (`showPremiumBottomSheet`, `SheetBody`) ·
`responsive.dart` (`Breakpoints`, `ContentShell`, `HoverLift`, `EntranceFade`) ·
`auth_shell.dart` · `booking_steps.dart`.

## Backend / API

- **`swift-fleet-api/server.js` must be running on :8787.** It proxies `/api/*`
  to `https://ecomapi.swift.ng` and injects the `X-Api-Key`. Start it with the
  managed node: `node swift-fleet-api/server.js`. Nothing works without it.
- **`ApiService` runs requests untyped and applies the caller's `fromJson`.**
  Never ask Dio for a concrete type directly — the API enveloped its payloads
  as `{Success, Message, Data:{…}}` and the cast fails, surfacing as a bogus
  "network error".
- **Parse responses with `ApiEnvelope`** (`lib/utils/api_envelope.dart`).
  `Data` is sometimes the list (routes) and sometimes a map containing it
  (locations, trips). Never look for list keys only at the top level.
- **The fleet catalog is a public store-scoped read** (`X-Api-Key` +
  `apiKey`/`storeId` query params). **Do not forward the user's bearer token**
  to `/trips/locations`, `/trips/routes` or `/trips/search` — the upstream
  rejects it (401). `ApiService._send` also retries once without the token as a
  safety net.
- **The backend currently has no trip data.** Locations (Abuja/Jos/Lagos) and
  7 routes exist, but every route/date returns `Trips: []` with
  `"No trips available for the selected route and date"`. Empty search results
  are a data gap, not a bug.
- **Debugging tools**: `ApiService.debugLogging` (on in debug) prints every
  exchange; the `/api-diagnostics` screen shows base URL, per-endpoint status,
  latency, row count and raw bodies. `ApiService.log` is the in-memory buffer.

## Testing traps

- **`testWidgets()` swaps `HttpClient` for a mock that returns 400 with an
  empty body for every request.** Widget tests can never reach the real
  backend. Real network checks belong in plain `test()` files — see
  `test/live_api_probe_test.dart`, which skips itself when the proxy is down.
- `test/api_envelope_test.dart` is the offline regression guard for the
  envelope-parsing bug (uses verbatim captured payloads).

## Conventions / traps

- **`PremiumCard` is a `DecoratedBox` surface.** A bare `ListTile` /
  `SwitchListTile` inside it trips Flutter's "ink splashes may be invisible"
  assertion. `PremiumCard` already inserts a transparent `Material` for this —
  keep it that way. Same rule applies to any new decorated container that
  hosts list tiles.
- **Widget tests use a wider fallback font than Inter.** Never wrap a button
  in a tight `SizedBox(width: N)`; give labels `Flexible` + ellipsis.
- **Auth shell splits into two panes only at width >= 900.** Below that it
  uses the full-bleed hero + glass card layout (also what the 800px test
  viewport exercises).
- **Hero tags on trip cards are index-scoped** because the API can return
  duplicate `masterId`s.

## Running things in this environment

The shell has `HTTP_PROXY`/`HTTPS_PROXY` set to `http://127.0.0.1:56070`, which
breaks the `flutter_tester` loopback WebSocket. Always clear the proxy for
Flutter commands:

```
NO_PROXY="127.0.0.1,localhost" no_proxy="127.0.0.1,localhost" \
HTTP_PROXY= HTTPS_PROXY= http_proxy= https_proxy= flutter <analyze|test|build web>
```

## Regression suite

`test/dashboard_regression_test.dart` is the binding guardrail. It asserts
specific widget keys and copy — see the daily log for the full list. Any UI
change must keep those keys/strings and behaviours intact.

## Backend

`swift-fleet-api/` (single JS file) + `lib/services/`. No card PAN is ever
collected client-side — payment hands off to the gateway.

## Deployment — Render (single-origin, zero-dependency)

**One Node service serves the Flutter bundle *and* proxies the API.** Because
they share an origin, the client uses the relative path `/api/fleet`
(`ApiConfig` resolves `${Uri.base.origin}/api/fleet` when `kIsWeb`), so there is
no CORS preflight and no host baked into the bundle. `server.js` has **no npm
dependencies** — do not add any without a reason, it keeps free-tier cold starts
fast and removes the install step.

- **Service root is the repo root**, not `swift-fleet-api/` — Render must see
  `pubspec.yaml` and the server. The root `package.json` is a thin wrapper whose
  `start` delegates to `swift-fleet-api/server.js`.
- **Flutter web output goes to `swift-fleet-api/public/`** via
  `flutter build web --output` (never `build/web` — `/build/` is gitignored).
- **The proxy injects credentials server-side** (overwrites `apiKey`/`storeId`,
  sets `X-Api-Key`). The deployed client never carries the real key, and
  rotating it needs no rebuild. `API_KEY` is a `sync: false` Render secret.
- **SPA fallback only for extension-less paths** — `/trips` → `index.html`, but
  `/missing.js` → a real 404 so build mistakes stay visible.
- **`Accept-Encoding: identity`** upstream, because the server gzips itself.
- **RAM trap: `flutter build web` needs ~2 GB, Render free tier gives 512 MB.**
  Building on Render will likely OOM. Preferred path: build locally, commit
  `swift-fleet-api/public/`, use build command `npm install --omit=dev`.
- Full runbook: `DEPLOY.md`. Blueprint: `render.yaml` (health check `/health`).
