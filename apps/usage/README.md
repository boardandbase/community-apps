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
| `history` | samples over time (`t` = RFC3339 UTC, `p` = percent); last 60 kept |

## Setting up the data pump on Windows (from scratch)

`push_usage.py` logs into claude.ai with a real browser once, then runs headless to
read your usage and push it to a jsonbin bin.

**1. Install Python** — get it from [python.org](https://www.python.org/downloads/) and
tick **"Add Python to PATH"** during install. Check it:

```
python --version
```

**2. Install Playwright** (the browser the script drives):

```
pip install playwright
playwright install chromium
```

**3. Create a jsonbin bin** — sign up at [jsonbin.io](https://jsonbin.io) (free):

- **Create Bin** with `{"active": false}` and note the **Bin ID**.
- Create a **read/write Access Key** — the script writes with this.
- Either make the bin **public** (the app reads it without a key), or keep it private
  and create a separate **read-only** key for the app's `read_key` field.

**4. Find your org UUID** — logged into claude.ai, open
`https://claude.ai/api/organizations` and copy the `uuid`. Your usage URL is:

```
https://claude.ai/api/organizations/<UUID>/usage
```

**5. Configure the script** — create `usage_config.json` next to `push_usage.py`
(keep it private — it's git-ignored):

```json
{
  "bin_id": "<your bin id>",
  "access_key": "<jsonbin read/write key>",
  "usage_url": "https://claude.ai/api/organizations/<UUID>/usage"
}
```

(Or use environment variables `JSONBIN_BIN_ID`, `JSONBIN_ACCESS_KEY`,
`CLAUDE_USAGE_URL` instead.)

**6. Log in once:**

```
python push_usage.py --login
```

A browser opens — log into claude.ai, **leave the window open** and press ENTER in the
terminal. Your session is saved to `C:\Users\<you>\.claude_session`.

**7. Test it:**

```
python push_usage.py --show    # prints the raw usage JSON
python push_usage.py           # fetch → map → push (adds one history point)
```

Finally set the app's `api_url` to `https://api.jsonbin.io/v3/b/<BIN_ID>/latest`.

## Keeping it fresh — trigger it automatically

Pick one of these. The reset countdown recomputes live from `reset_at`, so a little
staleness between pushes doesn't matter.

### Option A — Windows Task Scheduler (always on, in the background)

Fastest via `schtasks` (`pythonw.exe` = no console window popping up each run):

```
schtasks /create /tn "ClaudeUsage" ^
  /tr "\"C:\Path\to\pythonw.exe\" \"C:\Path\to\push_usage.py\"" ^
  /sc minute /mo 5
```

Find your Python path with `where python`. The script reads `usage_config.json`
relative to itself, so the working directory doesn't matter. Remove the task with:

```
schtasks /delete /tn "ClaudeUsage" /f
```

You *can* run it every minute (`/mo 1`), but note that's ~43k pushes/month — above the
free jsonbin limit (~10k/month). **Every ~5 minutes is plenty** (the app caches reads
for 60s anyway).

Prefer the GUI? Create a task with a **Daily** trigger set to *"Repeat task every 5
minutes for a duration of 1 day"*, action **Start a program** → `pythonw.exe`, with the
script path as the argument.

### Option B — Claude Code Stop hook (push after each turn)

If you mostly want to watch usage *while working with Claude*, add a Stop hook to
`~/.claude/settings.json` so it pushes exactly when something changes — no scheduled
task needed:

```json
{
  "hooks": {
    "Stop": [
      { "hooks": [ { "type": "command",
        "command": "python \"C:/Path/to/push_usage.py\"" } ] }
    ]
  }
}
```

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
