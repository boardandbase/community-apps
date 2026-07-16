"""
Home Assistant Trend - Pixlet/Tronbyt app for the 64x32 matrix.

Shows one sensor's recent history: the sensor name + current value on top and a
full-width trend line below, with an optional animated fill (ripple / pulse /
wave / sweep / scan / comet) at a selectable speed. Data comes straight from the
Home Assistant REST API (history endpoint) using a long-lived access token.

Leave the DEFAULT_* constants empty when sharing the .star (no secrets in code).
"""

load("http.star", "http")
load("math.star", "math")
load("re.star", "re")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

DEFAULT_URL = ""
DEFAULT_TOKEN = ""
DEFAULT_ENTITY = ""
DEFAULT_COLOR = "#0F9FFF"

# --- Colors -----------------------------------------------------------------
GRAY = "#8AA0A8"    # sensor name / message subtitle
WHITE = "#FFFFFF"   # current value
DIM = "#c3c8d4"     # setup hints
RED = "#ff5147"     # errors

W = 64
HEADER_H = 8        # name + current value
PLOT_H = 24         # 32 - HEADER_H
TTL = 300           # HTTP cache (s); a multi-hour trend changes slowly
TS_FMT = "2006-01-02T15:04:05Z07:00"

# --- Animation ----------------------------------------------------------------
FRAMES = 12         # frames per loop
PI = 3.141592653589793
FILL_F = 0.25       # base fill brightness relative to the line color
RIPPLE_AMP = 0.5    # ripple: strength (radial wave from the bottom-left)
RIPPLE_FREQ = 0.42  # ripple: wave density (same as the usage app)
PULSE_AMP = 0.5     # pulse: whole fill breathes +/- this fraction
WAVE_AMP = 0.55     # wave: horizontal travelling stripes strength
WAVE_FREQ = 0.5     # wave: stripe density
SWEEP_HALF = 7.0    # sweep: half-width (px) of the horizontal highlight band
SCAN_HALF = 4.0     # scan: half-height (px) of the vertical scan band
COMET_TRAIL = 10.0  # comet: length (px) of the tail behind the dot on the line
ANIMATIONS = ["none", "ripple", "pulse", "wave", "sweep", "scan", "comet"]

# Animation speed -> ms per frame (a full loop takes FRAMES * delay ms).
SPEEDS = {"slow": 150, "normal": 90, "fast": 45}
DEFAULT_SPEED = "normal"

HEXD = "0123456789abcdef"

# Anchored: only plain/scientific numbers pass; "unavailable"/"unknown" don't.
# The pre-check is required because Starlark's float() fails hard (no try/except).
NUM_RE = r"^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?$"

# =============================================================================
# HELPERS
# =============================================================================

def _message(title, sub, color):
    """Simple screen for setup hints / errors."""
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

def _clamp(v, lo, hi):
    if v < lo:
        return lo
    if v > hi:
        return hi
    return v

def _h2(n):
    n = int(_clamp(n, 0, 255))
    return HEXD[n // 16] + HEXD[n % 16]

def _qf(f):
    # Quantize a brightness factor so equal colors merge into runs (smaller webp).
    return int(f / 0.04 + 0.5) * 0.04

def _norm_color(c):
    """Normalize a schema.Color value to #rrggbb (expand #rgb, drop alpha)."""
    c = (c or "").strip()
    if not c.startswith("#"):
        c = "#" + c
    if len(c) == 4:  # #rgb
        c = "#" + c[1] * 2 + c[2] * 2 + c[3] * 2
    if len(c) == 9:  # #rrggbbaa
        c = c[:7]
    if len(c) != 7:
        return DEFAULT_COLOR
    return c

def _rgb(c):
    return [int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16)]

def _cellhex(rgb, f):
    return "#" + _h2(rgb[0] * f) + _h2(rgb[1] * f) + _h2(rgb[2] * f)

def _px(h, color):
    if color == None:
        return render.Box(width = 1, height = h)
    return render.Box(width = 1, height = h, color = color)

def _fmt_value(v):
    """Short value: >=100 no decimals, otherwise 1 decimal (trailing .0 dropped)."""
    neg = v < 0
    a = -v if neg else v
    if a >= 100:
        s = str(int(a + 0.5))
    else:
        tenths = int(a * 10 + 0.5)
        if tenths % 10 == 0:
            s = "%d" % (tenths // 10)
        else:
            s = "%d.%d" % (tenths // 10, tenths % 10)
    if neg and s != "0":
        s = "-" + s
    return s

def _parse_points(raw, now_unix):
    """History JSON -> sorted [(unix_ts, float)], non-numeric states skipped."""
    if type(raw) != "list" or len(raw) == 0:
        return []
    series = raw[0]
    if type(series) != "list":
        return []
    points = []
    for item in series:
        if type(item) != "dict":
            continue
        s = item.get("state")
        ts = item.get("last_changed") or item.get("last_updated")
        if type(s) != "string" or type(ts) != "string":
            continue
        if len(re.match(NUM_RE, s)) == 0:
            continue
        points.append((int(time.parse_time(ts).unix), float(s)))
    points = sorted(points)
    if len(points) > 0 and points[-1][0] < now_unix:
        points.append((now_unix, points[-1][1]))
    if len(points) == 1:
        points.append((points[0][0] + 1, points[0][1]))
    return points

def _y_lim(points):
    """Min/max with 10% margin; a flatline gets an absolute pad (span 0 breaks the scale)."""
    ys = [p[1] for p in points]
    lo = min(ys)
    hi = max(ys)
    span = hi - lo
    if span == 0:
        pad = abs(hi) * 0.05
        if pad == 0:
            pad = 1.0
        return (lo - pad, hi + pad)
    return (lo - span * 0.1, hi + span * 0.1)

# =============================================================================
# GRAPH (column renderer, cf. the usage app)
# =============================================================================

def _actual(cp, x):
    # Linear interpolation over control points [(x, value)] in pixel space.
    if x <= cp[0][0]:
        return cp[0][1]
    for i in range(1, len(cp)):
        if x <= cp[i][0]:
            denom = cp[i][0] - cp[i - 1][0]
            if denom <= 0:
                return cp[i][1]
            return cp[i - 1][1] + (cp[i][1] - cp[i - 1][1]) * (x - cp[i - 1][0]) / denom
    return cp[-1][1]

def _col_heights(points, start_unix, now_unix):
    """Per column (0..W-1) the line pixel measured from the bottom (0..PLOT_H-1),
    or None left of the first data point (sensor newer than the window)."""
    lo, hi = _y_lim(points)
    span_t = float(now_unix - start_unix)
    if span_t <= 0:
        span_t = 1.0
    cp = [((t - start_unix) * (W - 1) / span_t, v) for t, v in points]
    heights = []
    for x in range(W):
        if x < cp[0][0] - 0.5:
            heights.append(None)
        else:
            v = _actual(cp, x)
            heights.append(int(_clamp((v - lo) / (hi - lo), 0.0, 1.0) * (PLOT_H - 1) + 0.5))
    return heights

def _wrap_dist(x, ph):
    p = ph / (2 * PI) * W
    d = x - p if x > p else p - x
    if W - d < d:
        d = W - d
    return d

def _fill_factor(anim, ph, x, r):
    """Brightness factor for the fill pixel at row r (0 = bottom) in column x."""
    if anim == "ripple":
        dist = math.sqrt(x * x + r * r)
        return FILL_F * (1.0 + RIPPLE_AMP * math.sin(RIPPLE_FREQ * dist - ph))
    if anim == "pulse":
        return FILL_F * (1.0 + PULSE_AMP * math.sin(ph))
    if anim == "wave":
        return FILL_F * (1.0 + WAVE_AMP * math.sin(WAVE_FREQ * x - ph))
    if anim == "sweep":
        d = _wrap_dist(x, ph)
        if d < SWEEP_HALF:
            return FILL_F * (1.0 + 2.2 * (1.0 - d / SWEEP_HALF))
        return FILL_F
    if anim == "scan":
        band = (ph / (2 * PI)) * (PLOT_H - 1)  # travels up over the loop
        dv = band - r if band > r else r - band
        if dv < SCAN_HALF:
            return FILL_F * (1.0 + 2.0 * (1.0 - dv / SCAN_HALF))
        return FILL_F
    return FILL_F  # none / comet: flat fill (comet only touches the line)

def _line_factor(anim, ph, x):
    """Brightness factor for the line pixel in column x."""
    if anim == "sweep":
        d = _wrap_dist(x, ph)
        if d < SWEEP_HALF:
            return 1.0 + 0.6 * (1.0 - d / SWEEP_HALF)
    if anim == "comet":
        p = ph / (2 * PI) * W
        dd = p - x  # tail sits behind the head (at smaller x)
        if dd < 0:
            dd += W
        if dd < COMET_TRAIL:
            return 1.0 + 2.5 * (1.0 - dd / COMET_TRAIL)
    return 1.0

def _col(x, h, rgb, anim, ph):
    """One 1px graph column: transparent spacer, line pixel, animated fill below.
    Equal-color pixels are merged into segments (cf. _fill_col in the usage app)."""
    if h == None:
        return _px(PLOT_H, None)

    kids = []
    spacer = PLOT_H - 1 - h
    if spacer > 0:
        kids.append(_px(spacer, None))
    kids.append(_px(1, _cellhex(rgb, _clamp(_line_factor(anim, ph, x), 0.0, 4.0))))

    if h > 0:
        prev = None
        run = 0
        for r in range(h - 1, -1, -1):  # top of the fill down to the bottom
            fr = _qf(_clamp(_fill_factor(anim, ph, x, r), 0.06, 0.95))
            c = _cellhex(rgb, fr)
            if c == prev:
                run += 1
            else:
                if prev != None:
                    kids.append(_px(run, prev))
                prev = c
                run = 1
        if prev != None:
            kids.append(_px(run, prev))
    return render.Column(children = kids)

def _graph(heights, rgb, anim, ph):
    return render.Row(children = [_col(x, heights[x], rgb, anim, ph) for x in range(W)])

# =============================================================================
# SCREEN
# =============================================================================

def _header(name, value_str):
    name_w = W - 4 * len(value_str) - 2
    if name_w < 12:
        name_w = 12
    return render.Box(
        width = W,
        height = HEADER_H,
        child = render.Row(
            expanded = True,
            main_align = "space_between",
            cross_align = "center",
            children = [
                render.Marquee(
                    width = name_w,
                    child = render.Text(content = name, font = "tom-thumb", color = GRAY),
                ),
                render.Text(content = value_str, font = "tom-thumb", color = WHITE),
            ],
        ),
    )

def _screen(header, heights, rgb, anim, ph):
    return render.Column(children = [header, _graph(heights, rgb, anim, ph)])

# =============================================================================
# MAIN
# =============================================================================

def main(config):
    ha_url = (config.get("ha_url") or DEFAULT_URL).strip()
    token = (config.get("token") or DEFAULT_TOKEN).strip()
    entity = (config.get("entity_id") or DEFAULT_ENTITY).strip()
    if ha_url == "":
        return _message("HA TREND", "SET URL", DIM)
    if token == "":
        return _message("HA TREND", "SET TOKEN", DIM)
    if entity == "":
        return _message("HA TREND", "SET ENTITY", DIM)

    name = (config.get("display_name") or "").strip()
    if name == "":
        name = entity.split(".", 1)[-1].replace("_", " ")
    unit = (config.get("unit") or "").strip()

    hours_raw = (config.get("hours") or "24").strip()
    hours = int(hours_raw) if len(re.match(r"^[0-9]+$", hours_raw)) > 0 else 24
    color = _norm_color(config.get("line_color") or DEFAULT_COLOR)
    anim = (config.get("animation") or "ripple").strip()
    if anim not in ANIMATIONS:
        anim = "ripple"
    speed = (config.get("speed") or DEFAULT_SPEED).strip()
    delay = SPEEDS.get(speed, SPEEDS[DEFAULT_SPEED])

    now = time.now()
    start = now - time.parse_duration("%dh" % hours)
    now_unix = int(now.unix)
    start_unix = int(start.unix)
    url = (
        ha_url.rstrip("/") + "/api/history/period/" +
        start.in_location("UTC").format(TS_FMT) +
        "?filter_entity_id=" + entity +
        "&end_time=" + now.in_location("UTC").format(TS_FMT) +
        "&minimal_response&no_attributes"
    )
    resp = http.get(url, headers = {"Authorization": "Bearer " + token}, ttl_seconds = TTL)
    if resp.status_code == 401 or resp.status_code == 403:
        return _message(name, "BAD TOKEN", RED)
    if resp.status_code != 200:
        return _message(name, "HTTP %d" % resp.status_code, RED)

    points = _parse_points(resp.json(), now_unix)
    if len(points) == 0:
        return _message(name, "NO DATA", RED)

    value_str = _fmt_value(points[-1][1]) + unit
    header = _header(name, value_str)
    heights = _col_heights(points, start_unix, now_unix)
    rgb = _rgb(color)

    if anim == "none":
        return render.Root(child = _screen(header, heights, rgb, "none", 0.0))

    frames = []
    for f in range(FRAMES):
        ph = f * (2 * PI / FRAMES)
        frames.append(_screen(header, heights, rgb, anim, ph))
    return render.Root(delay = delay, child = render.Animation(children = frames))

# =============================================================================
# SCHEMA
# =============================================================================

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(id = "ha_url", name = "Home Assistant URL",
                        desc = "Base URL, e.g. http://homeassistant.local:8123", icon = "link"),
            schema.Text(id = "token", name = "Access token",
                        desc = "Long-lived access token (HA: Profile > Security)", icon = "key"),
            schema.Text(id = "entity_id", name = "Entity",
                        desc = "e.g. sensor.living_room_temperature", icon = "tag"),
            schema.Text(id = "display_name", name = "Name (optional)",
                        desc = "Title on screen; defaults to the entity id", icon = "font"),
            schema.Text(id = "unit", name = "Unit (optional)",
                        desc = "Shown after the value, e.g. °C or kWh", icon = "ruler"),
            schema.Dropdown(id = "hours", name = "Period",
                            desc = "How far back the trend looks", icon = "clock", default = "24",
                            options = [
                                schema.Option(display = "3 hours", value = "3"),
                                schema.Option(display = "6 hours", value = "6"),
                                schema.Option(display = "12 hours", value = "12"),
                                schema.Option(display = "24 hours", value = "24"),
                                schema.Option(display = "2 days", value = "48"),
                                schema.Option(display = "1 week", value = "168"),
                            ]),
            schema.Color(id = "line_color", name = "Line color",
                         desc = "Color of the trend line", icon = "brush", default = DEFAULT_COLOR,
                         palette = ["#0F9FFF", "#43E57A", "#FF9A3C", "#FF5147", "#D97757"]),
            schema.Dropdown(id = "animation", name = "Animation",
                            desc = "Effect on the graph fill / line", icon = "film", default = "ripple",
                            options = [
                                schema.Option(display = "Ripple", value = "ripple"),
                                schema.Option(display = "Pulse", value = "pulse"),
                                schema.Option(display = "Wave", value = "wave"),
                                schema.Option(display = "Sweep", value = "sweep"),
                                schema.Option(display = "Scan", value = "scan"),
                                schema.Option(display = "Comet", value = "comet"),
                                schema.Option(display = "None (static)", value = "none"),
                            ]),
            schema.Dropdown(id = "speed", name = "Animation speed",
                            desc = "How fast the animation runs", icon = "gaugeHigh", default = DEFAULT_SPEED,
                            options = [
                                schema.Option(display = "Slow", value = "slow"),
                                schema.Option(display = "Normal", value = "normal"),
                                schema.Option(display = "Fast", value = "fast"),
                            ]),
        ],
    )
