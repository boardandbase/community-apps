"""
Agents - Pixlet/Tronbyt-compatible app for the 64x32 matrix display.

Shows how many Claude agents are running and how many are done. Reads the latest
value from the Adafruit IO feed 'agent' (which Claude pushes to), the same way the
Terrarium app uses the 'terrarium' feed.

Expected feed value (JSON string):
  {"running": 2, "done": 5, "updated": "14:32", "tokens": 3600000}

The optional 'tokens' field (total token count) appears bottom-right, abbreviated
(e.g. 3.6K, 211M). If it is missing, nothing is shown.

RUN turns amber as soon as something is running (green when 0). DONE is green.

Config can be provided in two ways:
  - individual dashboard fields (Adafruit IO key / username / feed), or
  - all-in-one via the 'Parameters' field as "key=value; key2=value2", e.g.
    "aio_username=UserA; aio_key=aio_xxx; aio_feed=agent". Params win over the
    individual fields, so you can also pass them on the CLI:
        pixlet render agents.star 'params=aio_username=UserA; aio_key=aio_xxx'

Leave DEFAULT_KEY empty when sharing the .star with the community (no secrets in code).
"""

load("encoding/json.star", "json")
load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")

# --- Adafruit IO (cloud feed Claude pushes to) ------------------------------
AIO_BASE = "https://io.adafruit.com"  # generic API host; stays
# Everything below stays EMPTY in the code (no personal/secret values hardcoded, so the
# .star is clean to share). Fill it in via the dashboard fields or the 'params' string.
DEFAULT_USER = ""
DEFAULT_FEED = ""
DEFAULT_KEY = ""

# --- Colors -----------------------------------------------------------------
GREEN = "#6FCF97"   # title + 'done'
GRAY = "#8AA0A8"    # labels
AMBER = "#FFB020"   # 'running' when something is running
CYAN = "#3EC6FF"
RED = "#FF3B30"     # no data
WHITE = "#FFFFFF"

# =============================================================================
# HELPERS
# =============================================================================

def as_int(v):
    """Value to int; None/empty -> None."""
    if v == None:
        return None
    return int(v)

def parse_params(raw):
    """Split 'key=value; key2=value2' into a dict; empty/invalid parts are ignored."""
    out = {}
    if raw == None:
        return out
    for part in raw.split(";"):
        part = part.strip()
        if part == "" or "=" not in part:
            continue
        pair = part.split("=", 1)
        out[pair[0].strip()] = pair[1].strip()
    return out

def cfg(config, key, default):
    """Effective config value: first from the 'params' string, then the individual field, else default."""
    params = parse_params(config.get("params", ""))
    if key in params and params[key] != "":
        return params[key]
    v = config.get(key, None)
    if v != None and v.strip() != "":
        return v.strip()
    return default

def _abbr(v, div, suffix):
    """Divide v by div, round to 1 decimal and drop a trailing .0."""
    tenths = (v * 10 + div // 2) // div  # rounded to 1 decimal
    whole = tenths // 10
    dec = tenths % 10
    if dec == 0:
        return "%d%s" % (whole, suffix)
    return "%d.%d%s" % (whole, dec, suffix)

def fmt_tokens(v):
    """Abbreviated token count: <1e3 = the number itself, then x.xK / x.xM / x.xG.
    None when the value is missing. Examples: 3600 -> '3.6K', 211000000 -> '211M'."""
    if v == None:
        return None
    if v < 0:
        v = 0
    if v < 1000:
        return str(v)
    if v < 1000000:
        return _abbr(v, 1000, "K")
    if v < 1000000000:
        return _abbr(v, 1000000, "M")
    return _abbr(v, 1000000000, "G")

def metric_row(label, value, color):
    """Label (gray) + number (colored)."""
    return render.Row(
        cross_align = "center",
        children = [
            render.Text(content = label, font = "tb-8", color = GRAY),
            render.Box(width = 4, height = 1),
            render.Text(content = value, font = "tb-8", color = color),
        ],
    )

def message(title, sub, color):
    """Simple screen for error / no connection."""
    return render.Root(
        child = render.Column(
            expanded = True,
            main_align = "center",
            cross_align = "center",
            children = [
                render.Text(content = title, font = "tb-8", color = color),
                render.Box(width = 1, height = 2),
                render.Text(content = sub, font = "tb-8", color = GRAY),
            ],
        ),
    )

# =============================================================================
# MAIN
# =============================================================================

def fetch_data(config):
    """Fetch the latest feed value from Adafruit IO and json.decode it."""
    user = cfg(config, "aio_username", DEFAULT_USER)
    key = cfg(config, "aio_key", DEFAULT_KEY)
    if not (user and key):
        return None
    base = cfg(config, "aio_base", AIO_BASE)
    feed = cfg(config, "aio_feed", DEFAULT_FEED)
    url = base + "/api/v2/" + user + "/feeds/" + feed + "/data/last"
    resp = http.get(url, headers = {"X-AIO-Key": key}, ttl_seconds = 30)
    if resp.status_code != 200:
        return None
    val = resp.json().get("value")
    if val == None or val == "":
        return None
    return json.decode(val)

def main(config):
    data = fetch_data(config)
    if data == None:
        return message("Agents", "no data", RED)

    running = as_int(data.get("running"))
    done = as_int(data.get("done"))
    updated = data.get("updated", "")
    tokens_str = fmt_tokens(as_int(data.get("tokens")))

    run_str = "--" if running == None else str(running)
    done_str = "--" if done == None else str(done)
    run_color = AMBER if (running != None and running > 0) else GREEN

    title = render.Marquee(
        width = 64,
        child = render.Text(content = "Claude agents", font = "tb-8", color = GREEN),
    )

    rows = [
        title,
        metric_row("RUN", run_str, run_color),
        metric_row("DONE", done_str, GREEN),
    ]

    # Bottom row: 'updated' on the left, total tokens bottom-right (abbreviated, gray).
    updated_txt = render.Text(content = updated, font = "tb-8", color = GRAY)
    tokens_txt = render.Text(content = tokens_str, font = "tb-8", color = GRAY) if tokens_str != None else None
    if updated and tokens_txt != None:
        rows.append(render.Row(
            expanded = True,
            main_align = "space_between",
            children = [updated_txt, tokens_txt],
        ))
    elif tokens_txt != None:
        rows.append(render.Row(
            expanded = True,
            main_align = "end",
            children = [tokens_txt],
        ))
    elif updated:
        rows.append(updated_txt)

    return render.Root(
        child = render.Padding(
            pad = (2, 0, 2, 0),
            child = render.Column(
                expanded = True,
                main_align = "start",
                cross_align = "start",
                children = rows,
            ),
        ),
    )

# =============================================================================
# SCHEMA
# =============================================================================

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "aio_username",
                name = "Adafruit IO username",
                desc = "Your Adafruit IO username (io.adafruit.com)",
                icon = "user",
            ),
            schema.Text(
                id = "aio_key",
                name = "Adafruit IO key",
                desc = "Your AIO key (io.adafruit.com -> 'My Key')",
                icon = "key",
            ),
            schema.Text(
                id = "aio_feed",
                name = "Feed",
                desc = "Name of the feed the agent status is pushed to",
                icon = "rss",
            ),
            schema.Text(
                id = "params",
                name = "Parameters (all-in-one, optional)",
                desc = "key=value; key2=value2 (e.g. aio_username=UserA; aio_key=aio_xxx; aio_feed=agent). Overrides the individual fields above.",
                icon = "sliders",
            ),
        ],
    )
