# Deploying Swift Fleet to Render

One Web Service serves both the compiled Flutter app and the API proxy, so the
whole thing lives on a single public URL.

```
https://<your-service>.onrender.com
├── /                    → Flutter app (public/index.html)
├── /trips, /wallet, …   → Flutter app (SPA fallback to index.html)
├── /health              → {"status":"ok", …}
└── /api/fleet/*         → proxied to https://ecomapi.swift.ng (X-Api-Key + CORS)
```

Because the proxy is on the same origin as the app, the Flutter build calls
`/api/fleet` relatively — no hardcoded host, no CORS preflight, and the same
bundle works on Render, on a preview URL and on localhost.

---

## 0. Prerequisites

- A GitHub account (Render deploys from a Git repo).
- A Render account — https://render.com (free tier is fine).
- This project is **not currently a git repository**, so start here.

```bash
cd /path/to/fleet_booking
git init
git add .
git commit -m "Swift Fleet: Flutter web app + API proxy"
```

Create an empty repo on GitHub, then:

```bash
git remote add origin https://github.com/<you>/<repo>.git
git branch -M main
git push -u origin main
```

---

## 1. Local sanity check

Do this before deploying — it catches almost every problem early.

```bash
# Compile the Flutter web app into swift-fleet-api/public/
npm run build:web

# Run the combined server (serves the app AND proxies the API)
npm start
```

Open http://localhost:8787 — you should get the Flutter app, and
http://localhost:8787/health should return JSON. Then confirm the proxy:

```bash
curl "http://localhost:8787/api/fleet/trips/locations?apiKey=x&storeId=y"
```

If that returns the Abuja/Jos/Lagos JSON, the proxy is good.

---

## 2. Deploy — pick ONE option

### Option A — build Flutter on Render (blueprint default)

`render.yaml` already does this. The build installs the Flutter SDK, compiles
the bundle, then `server.js` serves it.

1. Render Dashboard → **New** → **Blueprint**.
2. Select your repository. Render reads `render.yaml` automatically.
3. When prompted for `API_KEY` (declared with `sync: false`), paste your store
   API key. It is stored as a secret and never committed.
4. **Apply** and wait. The first build takes roughly 5–12 minutes.

> ⚠️ `flutter build web` wants about 2 GB of RAM. The free tier gives the build
> container 512 MB, so this step **can be killed with an out-of-memory error**.
> If you see that, use Option B — it is faster and more reliable.

### Option B — prebuild locally, deploy the artifact (recommended)

Removes Flutter from the cloud build entirely.

```bash
npm run build:web          # produces swift-fleet-api/public/
```

Un-ignore the bundle so it gets committed — edit `.gitignore` and **delete**:

```
/swift-fleet-api/public/
```

Then commit and push:

```bash
git add -A
git commit -m "Add prebuilt web bundle"
git push
```

In `render.yaml`, swap the two command lines:

```yaml
buildCommand: npm install --omit=dev
startCommand: node swift-fleet-api/server.js
```

and delete the `FLUTTER_VERSION` env var. Deploy as in Option A. The build now
finishes in seconds.

> Note: you must re-run `npm run build:web` and push whenever the Dart code
> changes. That is the trade-off for the faster, more reliable build.

---

## 3. Environment variables

Set in the Render dashboard (**Environment** tab) or via `render.yaml`:

| Key | Required | Default | Purpose |
| --- | --- | --- | --- |
| `API_KEY` | recommended | built-in dev key | Injected as `X-Api-Key`; also overwrites the `apiKey` query param |
| `STORE_ID` | recommended | `bentalsupermarket` | Overwrites the `storeId` query param |
| `UPSTREAM_HOST` | no | `ecomapi.swift.ng` | Fleet backend host |
| `UPSTREAM_SCHEME` | no | `https` | `http` only for a local mock |
| `UPSTREAM_PORT` | no | `443` | Upstream port |
| `FLUTTER_VERSION` | no | `stable` | Pin the Flutter SDK for reproducible builds |
| `NODE_VERSION` | no | `22.22.2` | Node runtime |

Because the server enforces its own `API_KEY`/`STORE_ID`, you can rotate the
key in Render without rebuilding or redeploying the client.

---

## 4. Verify the deployment

```bash
# Health check — must be 200 with "status": "ok"
curl https://<your-service>.onrender.com/health

# The app
curl -I https://<your-service>.onrender.com/

# SPA deep link — must return index.html, not a 404
curl -I https://<your-service>.onrender.com/trips

# Proxy — must return the locations JSON
curl "https://<your-service>.onrender.com/api/fleet/trips/locations"
```

Then open the URL in a browser. In-app, go to
**Settings → Diagnostics → API connection** (or open `/api-diagnostics`) to see
the resolved base URL, per-endpoint status, latency and raw responses.

---

## 5. Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `/health` says `"status": "degraded"` | `public/index.html` missing | The Flutter build did not run or failed — check the build log, or use Option B |
| App loads, every API call fails | Upstream blocked or key wrong | Check `API_KEY` in Render; `curl …/api/fleet/trips/locations` and read the JSON `Message` |
| Blank page / old version after deploy | Service worker cache | Hard-reload (Ctrl/Cmd+Shift+R). `index.html` and `flutter_service_worker.js` are sent `no-store` by the server, so this should be rare |
| Build killed: "out of memory" | Flutter on the free tier | Use Option B |
| 502 from the proxy | Upstream unreachable or timed out (30 s) | The JSON body contains the upstream error message |
| First request after idle is slow | Free tier spins down after ~15 min | Expected. The browser warms it on the next visit |

Logs are in the Render dashboard under **Logs**. The server prints one line per
proxied request, with the API key redacted:

```
[2026-09-11T12:00:00.000Z] PROXY GET /api/fleet/trips/locations?apiKey=*** → 200 (184ms)
```

---

## 6. Free-tier caveats

- The service **sleeps after ~15 minutes of inactivity**; the next request takes
  ~30 s to wake it.
- 512 MB RAM and a shared CPU.
- 750 instance-hours/month.
- Render terminates TLS for you, so the app is HTTPS automatically. That is why
  the app can safely use a same-origin relative API path.

---

## Files involved

| File | Role |
| --- | --- |
| `swift-fleet-api/server.js` | The service: static hosting + `/api/*` proxy + `/health` |
| `swift-fleet-api/package.json` | Server metadata, `start` script, Node engine pin |
| `swift-fleet-api/scripts/build-web.js` | Cross-platform `flutter build web` into `public/` |
| `swift-fleet-api/public/` | Generated Flutter bundle (gitignored by default) |
| `scripts/render-build.sh` | Render build step: install Flutter, compile, verify |
| `render.yaml` | Render blueprint |
| `package.json` (root) | Deployment wrapper so Render detects a Node service |
| `lib/config/api_config.dart` | Resolves the API base to the page's own origin on web |
