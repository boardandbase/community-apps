# Claude Usage

Shows your **Claude session usage** on the 64×32 matrix and whether you'll run out of
tokens before your 5-hour session resets.

- A big **percentage** (top-left) and two **clock times** (top-right): when your
  tokens run out (white) and when the session resets (blue). If you're on track it
  shows **OK** + the reset time in green.
- An animated **color graph** filled up to your real usage: **green** below the ideal
  pace line, fading to **red** where you go above it.
- A dotted **marker** shows where your tokens run out; the gap to the right edge is
  how much time you fall short.
- At **100%** the display switches to an error state: a large red **100%** with a
  blinking **warning triangle**, and the run-out clock **freezes in red** on the
  moment you hit 100% (the dotted marker pins there too).
- With **Show history** on, "now" sits at the center (dim dotted line): the left
  half shows the past 2½ hours — grey where it belongs to a previous session — and
  the right half what's still ahead of you.
- An optional **name** bottom-right.

The app only *reads* a small JSON document from a URL. A companion script
(`push_usage.py`) produces that JSON from your real claude.ai usage.

## App settings

Open the app's settings on the display and fill these in:

| Field | id | Required | Example |
| --- | --- | --- | --- |
| Data URL | `api_url` | yes | `https://api.jsonbin.io/v3/b/<BIN_ID>/latest` |
| Access key | `read_key` | no | only for a **private** bin (a read-only key) |
| Name | `name` | no | `Martijn` |
| Timezone | `timezone` | no | `Europe/Amsterdam` |
| Show history | `show_history` | no | off by default; centers the graph on "now" with the past on the left |

Clock times use your device timezone; the Timezone field is only a fallback for
devices that don't provide one. With no `api_url` set, the app shows **SET URL**.

## The data

The app does an `http.get` on `api_url` and expects this JSON (a jsonbin.io bin wraps
it in `{"record": {...}}`, which the app also handles):

```json
{
  "active": true,
  "percent": 62,
  "reset_at": "2026-07-13T16:10:00Z",
  "history": [
    {"t": "2026-07-13T13:00:00Z", "p": 30},
    {"t": "2026-07-13T13:30:00Z", "p": 41}
  ]
}
```

| field | meaning |
| --- | --- |
| `active` | `false` → the app shows `IDLE`; `true` → it renders the graph |
| `percent` | current session usage, 0–100 |
| `reset_at` | when the 5-hour session window resets (RFC3339, UTC `…Z`) |
| `history` | samples over time (`t` = RFC3339 UTC, `p` = percent); last 120 kept |

## Producing the data

The app only *reads* JSON — something has to refresh it periodically. Two routes:

### No laptop (recommended) — GitHub Actions

Run the pump on a free GitHub Actions cron. **Fork-and-go reference repo:**
[JansenDevelopment/claude-usage-data](https://github.com/JansenDevelopment/claude-usage-data)
— fork it, add a few secrets, and point this app's `api_url` at your fork. It supports
two routes: the app reading straight from the **GitHub raw URL** (simplest, no jsonbin),
or from a **jsonbin bin** (freshest, and a laptop hook can feed the same bin). Full
monkeyproof steps for both are in that repo's README.

### Local — the bundled `push_usage.py` → jsonbin

`push_usage.py` (in this folder) logs into claude.ai once with a real browser, then runs
headless to read your usage and push it to a free jsonbin bin.

1. `pip install playwright && playwright install chromium`
2. Create a free [jsonbin.io](https://jsonbin.io) bin; note its **Bin ID** and a
   **read/write Access Key**.
3. Find your org UUID at `https://claude.ai/api/organizations`; your usage URL is
   `https://claude.ai/api/organizations/<UUID>/usage`.
4. Put `bin_id`, `access_key` and `usage_url` in `usage_config.json` next to the script
   (git-ignored), or use env vars `JSONBIN_BIN_ID` / `JSONBIN_ACCESS_KEY` /
   `CLAUDE_USAGE_URL`.
5. `python push_usage.py --login` (log in, leave the browser open, press ENTER), then
   `python push_usage.py` to test.
6. Set the app's `api_url` to `https://api.jsonbin.io/v3/b/<BIN_ID>/latest`.

**Keep it fresh:** schedule it, e.g. Windows Task Scheduler every ~5 min —
`schtasks /create /tn ClaudeUsage /tr "\"C:\path\pythonw.exe\" \"C:\path\push_usage.py\"" /sc minute /mo 5`.
The countdown recomputes live from `reset_at`, so light staleness is fine; stay under
jsonbin's free ~10k writes/month.

## Cookies / logging in again — how often and why

- The script queries `/usage` as **your logged-in claude.ai session** (cookies in
  `~/.claude_session`). That's why it needs no claude.ai API key.
- Those session cookies last a **long time (weeks)** but eventually expire.
- There's **no fixed interval** — you only log in again **when a push fails**. The
  script tells you so itself: *"usage endpoint … log in again? (--login)"*. Just run
  `python push_usage.py --login` again and the scheduled task works once more.
- Why they expire: once the session is no longer valid, claude.ai / Cloudflare rejects
  the request — there's no valid cookie left to authenticate with.

## Keep it private

Never commit `usage_config.json`, `~/.claude_session`, or your keys. The `/usage`
endpoint is internal and unofficial, so it may change.

## Files

| file | role |
| --- | --- |
| `claudeusage.star` | the app — this is what you add to the store |
| `manifest.yaml` | store metadata (name, summary, author) |
| `push_usage.py` | companion data pump (runs on your PC) |
