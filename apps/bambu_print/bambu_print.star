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

API_BASE = "https://api.bambulab.com"

ACCENT = "#f59e0b"
ACCENT_LIGHT = "#ffd37a"
WHITE = "#ffffff"
DIM = "#9ca3af"
BG = "#000000"  # pure black: background pixels stay off
BAR_BG = "#262626"
BAR_W = 60

# state -> (dim, mid, bright) colors for the pulsing status dot
STATES = {
    "RUNNING": ("#15803d", "#22c55e", "#86efac"),
    "PREPARE": ("#1d4ed8", "#3b82f6", "#93c5fd"),
    "SLICING": ("#1d4ed8", "#3b82f6", "#93c5fd"),
    "PAUSE": ("#b45309", ACCENT, ACCENT_LIGHT),
    "FINISH": ("#1d4ed8", "#3b82f6", "#93c5fd"),
    "FAILED": ("#991b1b", "#ef4444", "#fca5a5"),
    "IDLE": ("#374151", "#6b7280", "#9ca3af"),
    "OFFLINE": ("#991b1b", "#ef4444", "#fca5a5"),
}

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

def pulse_dot(colors):
    dim, mid, bright = colors
    seq = [dim, dim, dim, mid, mid, bright, bright, bright, mid, mid, dim, dim]
    return render.Box(
        width = 6,
        height = 7,
        child = render.Animation(
            children = [render.Circle(diameter = 5, color = c) for c in seq],
        ),
    )

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
                pad = (2, 1, 2, 1),
                child = render.Column(children = children),
            ),
        ),
    )

def error_screen(title, big):
    return screen([
        header("OFFLINE", shorten(title, 24)),
        render.Box(width = 60, height = 2),
        render.Text(big, font = "tb-8", color = "#ef4444"),
        render.Box(width = 60, height = 3),
        render.Box(width = BAR_W, height = 4, color = BAR_BG),
    ])

def main(config):
    token = ""
    for key in ["access_token", "access_token_2", "access_token_3", "access_token_4", "access_token_5"]:
        token += config.get(key, "").strip()
    wanted = config.get("printer_name", "").strip()

    if token == "":
        # Demo data so the app renders with zero parameters.
        st = {
            "name": "P1S",
            "online": True,
            "state": "RUNNING",
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
        big, big_color = "DONE", "#3b82f6"
    elif state == "FAILED":
        big, big_color = "FAIL", "#ef4444"
    elif state == "IDLE":
        big, big_color = "IDLE", DIM
    else:
        big, big_color = "%d%%" % pct, ACCENT

    active = state in ["RUNNING", "PAUSE", "PREPARE", "SLICING"]
    time_txt = fmt_remaining(remaining) if active else "--"
    label_txt = "left" if active else "cloud"

    filled = pct * BAR_W // 100
    if pct > 0 and filled == 0:
        filled = 1
    bar = []
    if filled >= 2:
        bar.append(render.Box(width = filled - 1, height = 4, color = big_color))
        bar.append(render.Box(width = 1, height = 4, color = ACCENT_LIGHT))
    elif filled == 1:
        bar.append(render.Box(width = 1, height = 4, color = ACCENT_LIGHT))
    if BAR_W - filled > 0:
        bar.append(render.Box(width = BAR_W - filled, height = 4, color = BAR_BG))

    return screen([
        header(state, title),
        render.Box(width = 60, height = 1),
        render.Row(
            cross_align = "center",
            children = [
                render.Box(
                    width = 24,
                    height = 13,
                    child = render.Text(big, font = "6x13", color = big_color),
                ),
                render.Box(width = 2, height = 1),
                render.Box(
                    width = 34,
                    height = 13,
                    child = render.Column(
                        children = [
                            render.Marquee(
                                width = 34,
                                child = render.Text(label_txt, font = "tom-thumb", color = DIM),
                            ),
                            render.Marquee(
                                width = 34,
                                child = render.Text(time_txt, font = "tom-thumb", color = WHITE),
                            ),
                        ],
                    ),
                ),
            ],
        ),
        render.Box(width = 60, height = 3),
        render.Row(children = bar),
    ])
