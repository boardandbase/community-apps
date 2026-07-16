# Home Assistant Trend

Shows the **recent history of one Home Assistant sensor** as a full-width trend
line on the 64×32 matrix.

- The **sensor name** and its **current value** (with unit) sit on top.
- Below, a **full-width trend line** with a dimmed fill traces the sensor over
  the chosen period (3 h to a week).
- An optional **animation** — ripple, pulse, wave, sweep, scan or comet — brings
  the fill to life, at a slow / normal / fast speed.
- The vertical scale auto-fits the data (a flat sensor still draws a clean line).

Data comes straight from the Home Assistant REST API (`/api/history/period`)
using a long-lived access token — no push script, add-on or intermediate storage
needed. The `.star` contains no secrets (the `DEFAULT_*` constants stay empty), so
it is safe to share; the token only lives in the app settings.

## App settings

Open the app's settings on the display and fill these in:

| Field | id | Required | Example |
| --- | --- | --- | --- |
| Home Assistant URL | `ha_url` | yes | `http://homeassistant.local:8123` |
| Access token | `token` | yes | a long-lived access token |
| Entity | `entity_id` | yes | `sensor.living_room_temperature` |
| Name | `display_name` | no | `Living room` (default: the entity id after the dot) |
| Unit | `unit` | no | `°C` |
| Period | `hours` | no | `24` — one of 3, 6, 12, 24, 48, 168 hours |
| Line color | `line_color` | no | `#0F9FFF` |
| Animation | `animation` | no | `ripple` (default), `pulse`, `wave`, `sweep`, `scan`, `comet` or `none` |
| Animation speed | `speed` | no | `normal` (default), `slow` or `fast` |

## Animations

The animations run over a 12-frame loop (speed = 150 / 90 / 45 ms per frame):

- **Ripple** — a brightness wave rolls through the fill from the bottom-left.
- **Pulse** — the whole fill breathes brighter and darker.
- **Wave** — bright vertical stripes drift horizontally across the fill.
- **Sweep** — a soft highlight band runs along the line, left to right.
- **Scan** — a bright horizontal band scans vertically through the fill.
- **Comet** — a bright dot with a fading tail races along the trend line.
- **None** — a static fill, no animation.

## Creating a token

1. In Home Assistant, click your user name (bottom of the sidebar) → **Security**.
2. Scroll to **Long-lived access tokens** → **Create token**.
3. Give it a name (e.g. `tidbyt`) and paste the token into the app's settings.

## Reachability

Whatever renders the app must be able to reach the Home Assistant URL:

- **Tronbyt / self-hosted pixlet on your LAN** — use the local URL, e.g.
  `http://homeassistant.local:8123` or `http://192.168.x.x:8123`.
- **Renderer outside your network** — use a remotely reachable URL, e.g. your
  Nabu Casa URL `https://xxx.ui.nabu.casa`.

Responses are cached for 5 minutes (`ttl_seconds = 300`), so a busy sensor won't
hammer Home Assistant.

## Troubleshooting

The app tells you what's wrong right on the display:

- **`SET URL` / `SET TOKEN` / `SET ENTITY`** — a required field is still empty.
- **`BAD TOKEN`** — the token was rejected (401/403); create a fresh one.
- **`HTTP <n>`** — Home Assistant answered with another error code.
- **`NO DATA`** — unknown entity, no history in the window, or only non-numeric
  states (e.g. `unavailable`) in range.

## Files

| file | role |
| --- | --- |
| `HomeAssistantTrend.star` | the app — this is what you add to the store |
| `manifest.yaml` | store metadata (name, summary, author) |
