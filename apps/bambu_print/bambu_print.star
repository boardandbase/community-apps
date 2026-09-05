load("render.star", "render")
load("http.star", "http")
load("time.star", "time")

# Bambu Lab P1S print-progress screen via Bambu Cloud.
#
# Needs your Bambu Cloud access token (Bearer). Tokens can be long, so you may
# split it over access_token, access_token_2 ... access_token_5 (they are
# simply joined in that order).
#
# Cloud calls used (max 2):
#   GET /v1/iot-service/api/user/bind          -> printers, online, print_status
#   GET /v1/user-service/my/tasks?deviceId=..  -> current job, startTime, costTime
# Progress is elapsed time / estimated cost time.
# For the Chinese cloud change API_BASE to https://api.bambulab.cn
#
# Layout (64x32):
#   row 1..7    pulsing state dot + scrolling "printer > job" title
#   row 8..20   mini printer building the model layer by layer (nozzle moves),
#               big percentage, time left
#   row 24..29  gradient progress bar with a light sweep while printing

API_BASE = "https://api.bambulab.com"

WHITE = "#ffffff"
DIM = "#9ca3af"
BG = "#000000"  # pure black: background pixels stay off
BAR_BG = "#1f1f1f"
BAR_W = 60
BAR_H = 6

FRAMES = 16  # animation frames per loop (80 ms each -> 1.3 s)

# (dark, mid, light) palettes
THEMES = {
    "active": ("#b45309", "#f59e0b", "#ffd37a"),  # amber, like a hot nozzle
    "pause": ("#b45309", "#f59e0b", "#ffd37a"),
    "done": ("#1d4ed8", "#3b82f6", "#93c5fd"),
    "fail": ("#991b1b", "#ef4444", "#fca5a5"),
    "idle": ("#374151", "#6b7280", "#9ca3af"),
}

# state -> (dim, mid, bright) colors for the pulsing status dot
STATES = {
    "RUNNING": ("#15803d", "#22c55e", "#86efac"),
    "PREPARE": ("#1d4ed8", "#3b82f6", "#93c5fd"),
    "SLICING": ("#1d4ed8", "#3b82f6", "#93c5fd"),
    "PAUSE": ("#b45309", "#f59e0b", "#ffd37a"),
    "FINISH": ("#1d4ed8", "#3b82f6", "#93c5fd"),
    "FAILED": ("#991b1b", "#ef4444", "#fca5a5"),
    "IDLE": ("#374151", "#6b7280", "#9ca3af"),
    "OFFLINE": ("#991b1b", "#ef4444", "#fca5a5"),
}

BED = "#6b7280"
BED_EDGE = "#9ca3af"
NOZZLE = "#e5e7eb"
NOZZLE_TIP = "#fca5a5"  # hot tip

HEX = "0123456789abcdef"

# ---------------------------------------------------------------- helpers

def to_int(v, fallback):
    t = type(v)
    if t == "int":
        return v
    if t == "float":
        return int(v)
    if t == "string":
        s = v.strip()
        if s.isdigit():
            return int(s)
        parts = s.split(".")
        if len(parts) == 2 and parts[0].isdigit() and parts[1].isdigit():
            return int(parts[0])
    return fallback

def clamp(v, lo, hi):
    if v < lo:
        return lo
    if v > hi:
        return hi
    return v

def shorten(s, n):
    cps = list(s.codepoints())
    if len(cps) > n:
        return "".join(cps[:n - 1]) + "~"
    return s

def fmt_remaining(mins):
    if mins <= 0:
        return "--"
    h = mins // 60
    m = mins % 60
    if h > 0:
        return "%dh%sm" % (h, ("0" + str(m))[-2:])
    return "%dm" % m

def hex2(v):
    v = clamp(v, 0, 255)
    return HEX[v // 16] + HEX[v % 16]

def rgb(h):
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16))

def lerp(a, b, t):
    # t in 0..1000 (integer permille) to stay in integer math
    ra, ga, ba = rgb(a)
    rb, gb, bb = rgb(b)
    return "#" + hex2(ra + (rb - ra) * t // 1000) + hex2(ga + (gb - ga) * t // 1000) + hex2(ba + (bb - ba) * t // 1000)

def safe_parse_time(s):
    # Accepts "2024-05-01T12:34:56Z" or with fractional seconds / offset.
    if type(s) != "string" or len(s) < 19:
        return None
    core = s[:19]
    digits = [0, 1, 2, 3, 5, 6, 8, 9, 11, 12, 14, 15, 17, 18]
    for i in digits:
        if not core[i].isdigit():
            return None
    if core[4] != "-" or core[7] != "-" or core[10] != "T" or core[13] != ":" or core[16] != ":":
        return None
    return time.parse_time(core + "Z", format = "2006-01-02T15:04:05Z")

# ---------------------------------------------------------------- cloud

def cloud_get(path, token):
    return http.get(
        API_BASE + path,
        ttl_seconds = 60,
        headers = {
            "Authorization": "Bearer " + token,
            "User-Agent": "bambu_network_agent/01.09.05.01",
        },
    )

def pick_device(devices, wanted):
    if len(devices) == 0:
        return None
    if wanted != "":
        for d in devices:
            if type(d) == "dict" and str(d.get("name", "")).lower() == wanted.lower():
                return d
    for d in devices:
        if type(d) == "dict":
            return d
    return None

def fetch_cloud(token, wanted):
    resp = cloud_get("/v1/iot-service/api/user/bind", token)
    if resp.status_code != 200:
        return None
    data = resp.json()
    if type(data) != "dict" or type(data.get("devices")) != "list":
        return None
    dev = pick_device(data["devices"], wanted)
    if dev == None:
        return None

    st = {
        "name": str(dev.get("name", "P1S")),
        "online": dev.get("online", False) == True,
        "state": str(dev.get("print_status", "IDLE")).upper(),
        "job": "",
        "pct": 0,
        "remaining": 0,
    }

    dev_id = str(dev.get("dev_id", ""))
    if dev_id == "":
        return st

    tresp = cloud_get("/v1/user-service/my/tasks?deviceId=" + dev_id + "&limit=1", token)
    if tresp.status_code != 200:
        return st
    tdata = tresp.json()
    if type(tdata) != "dict" or type(tdata.get("hits")) != "list" or len(tdata["hits"]) == 0:
        return st
    task = tdata["hits"][0]
    if type(task) != "dict":
        return st

    st["job"] = str(task.get("title", "")).strip()
    cost = to_int(task.get("costTime"), 0)  # estimated seconds
    start = safe_parse_time(task.get("startTime"))
    if start != None and cost > 0:
        elapsed = int((time.now() - start).seconds)
        elapsed = clamp(elapsed, 0, cost)
        st["pct"] = elapsed * 100 // cost
        st["remaining"] = (cost - elapsed + 59) // 60
    return st

# ---------------------------------------------------------------- drawing

def pixel_row(pixels, height = 1):
    # pixels: list of colors (or None for off). Merges runs into as few boxes as possible.
    boxes = []
    run_color = pixels[0]
    run_len = 0
    for c in pixels:
        if c == run_color:
            run_len += 1
        else:
            boxes.append(render.Box(width = run_len, height = height, color = run_color or BG))
            run_color = c
            run_len = 1
    boxes.append(render.Box(width = run_len, height = height, color = run_color or BG))
    return render.Row(children = boxes)

def pulse_dot(colors):
    dim, mid, bright = colors
    # smooth breathe over FRAMES frames
    steps = [0, 150, 350, 600, 800, 950, 1000, 950, 800, 600, 350, 150, 0, 0, 0, 0]
    frames = []
    for s in steps:
        c = lerp(dim, mid, s * 2) if s <= 500 else lerp(mid, bright, (s - 500) * 2)
        frames.append(render.Circle(diameter = 5, color = c))
    return render.Box(width = 6, height = 7, child = render.Animation(children = frames))

ICON_W = 12
ICON_H = 13
MODEL_X0 = 2  # model spans columns 2..9 (8 wide)
MODEL_W = 8
MODEL_ROWS = 10  # rows 2..11; row 12 is the bed; rows 0..1 are for the nozzle

def printer_icon(pct, mode, theme, frame):
    # mode: "active" (nozzle moves), "pause", "done", "fail", "idle"
    dark, mid, light = theme
    full = clamp(pct * MODEL_ROWS // 100, 0, MODEL_ROWS)
    if mode == "done":
        full = MODEL_ROWS
    if mode == "idle":
        full = 0

    # partial (currently printing) layer, columns filled left -> right
    printing = mode in ["active", "pause", "fail"] and full < MODEL_ROWS
    if mode == "active":
        part = (frame * (MODEL_W + 1)) // FRAMES  # 0..8
    else:
        part = MODEL_W // 2
    if not printing:
        part = 0

    grid = []
    for r in range(ICON_H):
        grid.append([None] * ICON_W)

    # bed
    for x in range(ICON_W):
        grid[ICON_H - 1][x] = BED
    grid[ICON_H - 1][0] = BED_EDGE
    grid[ICON_H - 1][ICON_W - 1] = BED_EDGE

    # finished layers, striped for a layered look
    for i in range(full):
        r = ICON_H - 2 - i
        c = mid if i % 2 == 0 else dark
        for x in range(MODEL_W):
            grid[r][MODEL_X0 + x] = c

    # layer in progress + nozzle
    if printing:
        r = ICON_H - 2 - full
        for x in range(part):
            grid[r][MODEL_X0 + x] = light
        nx = MODEL_X0 + clamp(part, 0, MODEL_W - 1)
        if mode == "active" and part > 0 and part < MODEL_W:
            # fresh filament under the nozzle glows
            grid[r][nx] = WHITE
        grid[r - 2][nx - 1] = NOZZLE
        grid[r - 2][nx] = NOZZLE
        grid[r - 2][nx + 1] = NOZZLE
        grid[r - 1][nx] = NOZZLE_TIP if mode == "active" else NOZZLE
    elif mode == "idle":
        # parked nozzle, top-left
        grid[0][MODEL_X0] = NOZZLE
        grid[0][MODEL_X0 + 1] = NOZZLE
        grid[0][MODEL_X0 + 2] = NOZZLE
        grid[1][MODEL_X0 + 1] = NOZZLE
    elif mode == "done":
        # a sparkle above the finished model
        spark = [(0, 5), (1, 8), (0, 1), (1, 3)]
        sr, sc = spark[(frame // 4) % len(spark)]
        grid[sr][sc] = light if (frame % 4) < 2 else WHITE

    return render.Column(children = [pixel_row(row) for row in grid])

def progress_bar(pct, mode, theme, frame):
    dark, mid, light = theme
    filled = pct * BAR_W // 100
    if pct > 0 and filled == 0:
        filled = 1
    sweep = -6
    if mode == "active":
        sweep = (frame * (BAR_W + 12)) // FRAMES - 6  # travels the whole bar each loop
    pixels = []
    for x in range(BAR_W):
        if x < filled:
            c = lerp(dark, light, x * 1000 // (BAR_W - 1))
            d = x - sweep
            if d < 0:
                d = -d
            if d == 0:
                c = lerp(c, WHITE, 750)
            elif d == 1:
                c = lerp(c, WHITE, 400)
            elif d == 2:
                c = lerp(c, WHITE, 150)
            if x == filled - 1 and filled > 1:
                c = lerp(c, WHITE, 500)  # bright leading edge
        else:
            c = BAR_BG
        pixels.append(c)

    # rounded ends: soften the corner pixels
    top = list(pixels)
    bottom = list(pixels)
    top[0] = None
    bottom[0] = None
    top[BAR_W - 1] = None
    bottom[BAR_W - 1] = None
    return render.Column(children = [
        pixel_row(top),
        pixel_row(pixels, BAR_H - 2),
        pixel_row(bottom),
    ])

def animated(builder):
    return render.Animation(children = [builder(f) for f in range(FRAMES)])

def header(state, title):
    return render.Row(
        cross_align = "center",
        children = [
            pulse_dot(STATES[state]),
            render.Box(width = 2, height = 1),
            render.Marquee(
                width = 52,
                child = render.Text(title, font = "tom-thumb", color = DIM),
            ),
        ],
    )

def screen(children):
    return render.Root(
        delay = 80,
        child = render.Box(
            width = 64,
            height = 32,
            color = BG,
            child = render.Padding(
                pad = (2, 1, 2, 0),
                child = render.Column(children = children),
            ),
        ),
    )

def error_screen(title, big):
    theme = THEMES["fail"]
    return screen([
        header("OFFLINE", shorten(title, 24)),
        render.Box(width = 60, height = 1),
        render.Row(
            cross_align = "center",
            children = [
                render.Box(width = ICON_W, height = ICON_H, child = animated(lambda f: printer_icon(0, "idle", theme, f))),
                render.Box(width = 3, height = 1),
                render.Text(big, font = "6x13", color = theme[1]),
            ],
        ),
        render.Box(width = 60, height = 3),
        progress_bar(0, "idle", theme, 0),
    ])

# ---------------------------------------------------------------- main

def main(config):
    token = ""
    for key in ["access_token", "access_token_2", "access_token_3", "access_token_4", "access_token_5"]:
        token += config.get(key, "").strip()
    wanted = config.get("printer_name", "").strip()

    if token == "":
        # Demo data so the app renders with zero parameters.
        # demo=running|pause|done|fail|idle previews the other looks.
        demo = config.get("demo", "running").strip().lower()
        demo_state = {"pause": "PAUSE", "done": "FINISH", "fail": "FAILED", "idle": "IDLE"}.get(demo, "RUNNING")
        st = {
            "name": "P1S",
            "online": True,
            "state": demo_state,
            "job": "Benchy.3mf",
            "pct": 67,
            "remaining": 83,
        }
    else:
        st = fetch_cloud(token, wanted)
        if st == None:
            return error_screen("Bambu Cloud > check token", "NO CLOUD")
        if not st["online"]:
            return error_screen(st["name"] + " > offline", "OFFLINE")

    state = st["state"]
    if state not in STATES:
        state = "IDLE"

    pct = clamp(to_int(st["pct"], 0), 0, 100)
    if state == "FINISH":
        pct = 100
    if state == "IDLE":
        pct = 0
    remaining = st["remaining"]

    job = st["job"]
    if job == "" or state == "IDLE":
        job = state.lower()
    title = shorten(st["name"] + " > " + job, 24)

    if state == "FINISH":
        mode, big = "done", "DONE"
    elif state == "FAILED":
        mode, big = "fail", "FAIL"
    elif state == "IDLE":
        mode, big = "idle", "IDLE"
    elif state == "PAUSE":
        mode, big = "pause", "%d%%" % pct
    else:
        mode, big = "active", "%d%%" % pct
    theme = THEMES[mode]

    if mode == "active":
        time_txt, label_txt = fmt_remaining(remaining), "left"
    elif mode == "pause":
        time_txt, label_txt = fmt_remaining(remaining), "paused"
    elif mode == "done":
        time_txt, label_txt = "print", "ready"
    elif mode == "fail":
        time_txt, label_txt = "print", "error"
    else:
        time_txt, label_txt = "no", "job"

    return screen([
        header(state, title),
        render.Box(width = 60, height = 1),
        render.Row(
            cross_align = "center",
            children = [
                render.Box(
                    width = ICON_W,
                    height = ICON_H,
                    child = animated(lambda f: printer_icon(pct, mode, theme, f)),
                ),
                render.Box(width = 2, height = 1),
                render.Box(
                    width = 24,
                    height = ICON_H,
                    child = render.Text(big, font = "6x13", color = theme[1]),
                ),
                render.Box(width = 1, height = 1),
                render.Box(
                    width = 21,
                    height = ICON_H,
                    child = render.Column(
                        main_align = "center",
                        children = [
                            render.Marquee(
                                width = 21,
                                child = render.Text(time_txt, font = "tom-thumb", color = WHITE),
                            ),
                            render.Box(width = 21, height = 1),
                            render.Marquee(
                                width = 21,
                                child = render.Text(label_txt, font = "tom-thumb", color = DIM),
                            ),
                        ],
                    ),
                ),
            ],
        ),
        render.Box(width = 60, height = 3),
        animated(lambda f: progress_bar(pct, mode, theme, f)),
    ])
