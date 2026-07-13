load("render.star", "render")
load("http.star", "http")
load("time.star", "time")
load("schema.star", "schema")
load("math.star", "math")

# Visualizes Claude session usage. Reads a small JSON blob from a URL:
#   {"active": true, "percent": 0-100, "reset_at": "<RFC3339>", "history": [{"t","p"}]}
# Point "api_url" at any host that serves it (e.g. a free jsonbin.io bin).
# When no URL is set, a short setup hint is shown. See README.md for how to
# populate the data.
DEFAULT_URL = ""

BG = "#000000"
DIM = "#c3c8d4"          # dim text (reset clock / messages)
CLAUDE = "#d97757"       # OFF/IDLE header
NAME_COL = "#ff8a5c"     # name, bottom-right
BLUE = "#0f9fff"         # ideal line / reset clock
MARK = "#e8e8f0"         # marker + tokens-out clock
GREEN_POS = "#43e57a"    # positive state (you'll make it to the reset)
OUTLINE = "#00000070"    # semi-transparent outline behind the name
BAR_BG = "#26262b"
BAR_W = 60

W = 64
GH = 26                  # graph height (px), below the 6px header
WINDOW = 5 * 3600        # 5-hour session window (seconds)
GRAD = 6.0               # half-width (%) of the green<->red transition around the line
FRAMES = 12              # animation frames (ripple + glow)
DELAY = 90               # ms per frame
PI = 3.141592653589793
RIPPLE_AMP = 0.18        # ripple strength
RIPPLE_FREQ = 0.42       # ripple wave density
GLOW_AMP = 0.28          # glow strength on the red zone
MARKER_CUT = 4           # trim the dotted marker this many px at the bottom

# fill color stops: green -> orange -> red
G = [46, 168, 92]
O = [255, 154, 60]
R = [255, 81, 71]
HEXD = "0123456789abcdef"

def _pct_color(pct):
    if pct >= 80:
        return "#ff5147"
    if pct >= 50:
        return "#ffd60a"
    return "#43e57a"

def _clamp(v, lo, hi):
    if v < lo:
        return lo
    if v > hi:
        return hi
    return v

def _round(x):
    return int(x + 0.5)

def _h2(n):
    n = int(_clamp(n, 0, 255))
    return HEXD[n // 16] + HEXD[n % 16]

def _lerp(a, b, t):
    return a + (b - a) * t

def _grad_rgb(diff):
    # diff = pixel value - ideal value (%). Smooth green -> orange -> red.
    t = _clamp((diff + GRAD) / (2 * GRAD), 0.0, 1.0)
    if t < 0.5:
        k = t / 0.5
        return [_lerp(G[0], O[0], k), _lerp(G[1], O[1], k), _lerp(G[2], O[2], k)]
    k = (t - 0.5) / 0.5
    return [_lerp(O[0], R[0], k), _lerp(O[1], R[1], k), _lerp(O[2], R[2], k)]

def _qf(f):
    return _round(f / 0.07) * 0.07

def _cellhex(rgb, f):
    return "#" + _h2(rgb[0] * f) + _h2(rgb[1] * f) + _h2(rgb[2] * f)

def _px(h, color):
    if color == None:
        return render.Box(width = 1, height = h)
    return render.Box(width = 1, height = h, color = color)

def _outlined(txt, font, fg, outline):
    # Text with a 1px dark outline: 8 dark copies around it + the color on top.
    kids = []
    for off in [[0, 0], [1, 0], [2, 0], [0, 1], [2, 1], [0, 2], [1, 2], [2, 2]]:
        kids.append(render.Padding(
            pad = (off[0], off[1], 0, 0),
            child = render.Text(content = txt, font = font, color = outline),
        ))
    kids.append(render.Padding(
        pad = (1, 1, 0, 0),
        child = render.Text(content = txt, font = font, color = fg),
    ))
    return render.Stack(children = kids)

# --- OFF / IDLE / setup -------------------------------------------------------

def _frame(children):
    return render.Root(
        delay = 1000,
        child = render.Box(
            width = 64, height = 32, color = BG,
            child = render.Column(
                expanded = True, main_align = "space_between", cross_align = "center",
                children = children,
            ),
        ),
    )

def _message(big, big_color):
    return _frame([
        render.Text(content = "CLAUDE", font = "tom-thumb", color = CLAUDE),
        render.Text(content = big, font = "tb-8", color = big_color),
        render.Text(content = "SESSION", font = "tom-thumb", color = DIM),
    ])

def _bar(pct, color):
    fill = BAR_W * pct // 100
    if fill > BAR_W:
        fill = BAR_W
    kids = [render.Box(width = BAR_W, height = 3, color = BAR_BG)]
    if fill > 0:
        kids.append(render.Box(width = fill, height = 3, color = color))
    return render.Box(width = BAR_W, height = 3, child = render.Stack(children = kids))

# --- graph (column renderer) --------------------------------------------------

def _fill_col(av, iv, xc, ph):
    # One column: filled from the bottom up to the usage value (av). Each pixel is
    # colored by its height vs the ideal line (iv): green below, smoothly to red
    # above. On top: a ripple (brightness wave from the bottom-left) and a soft
    # glow on the red zone. Equal colors are merged into segments.
    fp = _clamp(_round(av * GH / 100.0), 0, GH)
    if fp == 0:
        return _px(GH, None)

    kids = []
    spacer = GH - fp
    if spacer > 0:
        kids.append(_px(spacer, None))

    prev = None
    run = 0
    for h in range(fp, 0, -1):               # from the top (highest pixel) down
        pv = (h / float(GH)) * 100.0
        diff = pv - iv
        rgb = _grad_rgb(diff)
        dist = math.sqrt(xc * xc + h * h)
        fr = 1.0 + RIPPLE_AMP * math.sin(RIPPLE_FREQ * dist - ph)
        if diff > 0:                          # red zone: soft glow
            fr = fr * (1.0 + GLOW_AMP * math.sin(ph))
        fr = _qf(_clamp(fr, 0.45, 1.45))
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

def _ideal_col(iv):
    ip = _clamp(_round(iv * GH / 100.0), 0, GH)
    above = _clamp(GH - ip, 0, GH - 1)
    return render.Column(children = [_px(above, None), _px(1, BLUE)])

def _marker_col(hit):
    if not hit:
        return _px(GH, None)
    kids = []
    for i in range(GH):
        if i >= GH - MARKER_CUT:
            kids.append(_px(1, None))       # shorter at the bottom
        else:
            kids.append(_px(1, MARK if i % 2 == 0 else None))
    return render.Column(children = kids)

def _actual(cp, x):
    if x <= cp[0][0]:
        return cp[0][1]
    for i in range(1, len(cp)):
        if x <= cp[i][0]:
            denom = cp[i][0] - cp[i - 1][0]
            if denom <= 0:
                return cp[i][1]
            return cp[i - 1][1] + (cp[i][1] - cp[i - 1][1]) * (x - cp[i - 1][0]) / denom
    return cp[-1][1]

def _hist_points(history, start, elapsed):
    pts = []
    for s in history:
        if type(s) != "dict":
            continue  # old format (bare number) -> skip
        t = s.get("t")
        p = s.get("p")
        if t == None or p == None:
            continue
        off = (time.parse_time(t) - start).seconds
        if off >= 0 and off <= elapsed:
            pts.append([off * W / float(WINDOW), p])
    return sorted(pts, key = lambda e: e[0])

def _layout(pct, times, middle, pct_color, name_txt):
    # Header: the clock times side by side (each [text, color]).
    hk = []
    first = True
    for tc in times:
        if not first:
            hk.append(render.Box(width = 3, height = 6))
        hk.append(render.Text(content = tc[0], font = "tom-thumb", color = tc[1]))
        first = False
    hk.append(render.Box(width = 1, height = 6))  # 1px right margin
    header = render.Box(width = W, height = 6, child = render.Row(
        expanded = True, main_align = "end", cross_align = "center", children = hk,
    ))
    base = render.Column(children = [header, render.Box(width = W, height = GH, child = middle)])
    pct_label = render.Padding(
        pad = (2, 1, 0, 0),
        child = render.Text(content = "%d%%" % pct, font = "tb-8", color = pct_color),
    )
    kids = [base, pct_label]
    # Name bottom-right (optional): pinned down (Padding) + right-aligned (Row
    # main_align "end") so any length sits neatly in the corner. A plain Box would
    # center a smaller child, hence the expanded Row.
    if name_txt:
        kids.append(render.Padding(
            pad = (0, 22, 0, 0),
            child = render.Box(width = W, height = 10, child = render.Row(
                expanded = True, main_align = "end", cross_align = "center",
                children = [
                    _outlined(name_txt, "tb-8", NAME_COL, OUTLINE),
                    render.Box(width = 1, height = 10),
                ],
            )),
        ))
    return render.Box(width = W, height = 32, color = BG, child = render.Stack(children = kids))

def _usage(pct, secs, history, reset_at, name, tz):
    pct_color = _pct_color(pct)

    # No reset_at -> no time graph; fall back to a centered bar.
    if not reset_at:
        mid = render.Column(
            expanded = True, main_align = "center", cross_align = "center",
            children = [_bar(pct, pct_color)],
        )
        return render.Root(delay = 1000, child = _layout(pct, [], mid, pct_color, name))

    reset = time.parse_time(reset_at)
    start = reset - time.parse_duration("%ds" % WINDOW)
    elapsed = WINDOW - secs
    if elapsed < 0:
        elapsed = 0
    nowX = _clamp(_round(elapsed * W / float(WINDOW)), 0, W)

    # Control points: start at 0, history points, current reading last.
    cp = [[0, 0]]
    for p in _hist_points(history, start, elapsed):
        cp.append(p)
    cp.append([nowX, pct])

    reset_clock = reset.in_location(tz).format("15:04")

    # Marker: where do the tokens run out (projection at average pace -> 100%)?
    show_hit = False
    xHit = -1
    exh_clock = None
    if elapsed > 0 and pct > 0:
        hit_sec = elapsed * 100.0 / pct
        if hit_sec < WINDOW:  # only if you run out before the reset
            show_hit = True
            xHit = _clamp(_round(hit_sec * W / float(WINDOW)), 0, W - 1)
            exh = time.now() + time.parse_duration("%ds" % int(hit_sec - elapsed))
            exh_clock = exh.in_location(tz).format("15:04")

    # Header: run out before reset -> tokens-out (white) + reset (blue).
    # Otherwise the positive state: "OK" + reset, both green.
    if show_hit:
        times = [[exh_clock, MARK], [reset_clock, BLUE]]
    else:
        times = [["OK", GREEN_POS], [reset_clock, GREEN_POS]]

    ideal_row = render.Row(children = [_ideal_col((x / float(W)) * 100.0) for x in range(W)])
    marker_row = render.Row(children = [_marker_col(show_hit and x == xHit) for x in range(W)])

    frames = []
    for f in range(FRAMES):
        ph = f * (2 * PI / FRAMES)
        fill_cols = []
        for x in range(W):
            iv = (x / float(W)) * 100.0
            av = _actual(cp, x) if x <= nowX else 0.0
            fill_cols.append(_fill_col(av, iv, x, ph))
        graph = render.Stack(children = [render.Row(children = fill_cols), ideal_row, marker_row])
        frames.append(_layout(pct, times, graph, pct_color, name))

    return render.Root(delay = DELAY, child = render.Animation(children = frames))

# --- data ---------------------------------------------------------------------

def main(config):
    url = config.get("api_url") or DEFAULT_URL
    if not url:
        return _message("SET URL", DIM)  # not configured yet

    read_key = config.get("read_key")
    headers = {"X-Access-Key": read_key} if read_key else {}

    resp = http.get(url, headers = headers, ttl_seconds = 60)
    if resp.status_code != 200:
        return _message("OFF", DIM)

    raw = resp.json()
    data = raw["record"] if type(raw) == "dict" and "record" in raw else raw
    if not data.get("active"):
        return _message("IDLE", DIM)

    pct = int(data.get("percent") or 0)

    secs = 0
    reset_at = data.get("reset_at")
    if reset_at:
        remaining = time.parse_time(reset_at) - time.now()
        secs = int(remaining.seconds)
        if secs < 0:
            secs = 0

    history = data.get("history") or []
    name = config.get("name") or ""
    # Manual timezone overrides; else the device timezone ($tz); else UTC.
    tz = config.get("timezone") or config.get("$tz") or "UTC"

    return _usage(pct, secs, history, reset_at, name, tz)

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "api_url",
                name = "Data URL",
                desc = "URL returning JSON {active, percent, reset_at, history}, e.g. a jsonbin.io bin",
                icon = "link",
            ),
            schema.Text(
                id = "read_key",
                name = "Access key (optional)",
                desc = "Only for a private jsonbin: a read-only X-Access-Key",
                icon = "key",
            ),
            schema.Text(
                id = "name",
                name = "Name (optional)",
                desc = "Shown bottom-right on the display",
                icon = "user",
            ),
            schema.Text(
                id = "timezone",
                name = "Timezone (optional)",
                desc = "IANA name, e.g. Europe/Amsterdam. Only needed if your device provides none.",
                icon = "clock",
            ),
        ],
    )
