load("render.star", "render")
load("time.star", "time")

TZ = "Europe/Amsterdam"

# (parameter key, label on screen, color)
BINS = [
    ("rest", "REST", "#a8b0bc"),
    ("gft", "GFT", "#5ee08a"),
    ("paper", "PAPER", "#58b4f0"),
]

# Example dates (DD-MM, comma separated) so the app renders without parameters.
DEFAULTS = {
    "rest": "13-01,27-01,10-02,24-02,10-03,24-03,07-04,21-04,05-05,19-05,02-06,16-06,30-06,14-07,28-07,11-08,25-08,08-09,22-09,06-10,20-10,03-11,17-11,01-12,15-12,29-12",
    "gft": "06-01,20-01,03-02,17-02,03-03,17-03,31-03,14-04,28-04,12-05,26-05,09-06,23-06,07-07,21-07,04-08,18-08,01-09,15-09,29-09,13-10,27-10,10-11,24-11,08-12",
    "paper": "29-01,12-03,23-04,04-06,16-07,27-08,08-10,19-11,30-12",
}

WHITE = "#f8f8f0"
ICON = "#5ee08a"
BG = "#000000"

# Tall thin 9x15 pixel font for the bin name.
SIDES = ["#.......#"]
LEFT = ["#........"]
RIGHT = ["........#"]
GLYPHS = {
    "P": ["########."] + SIDES * 6 + ["########."] + LEFT * 7,
    "A": [".#######."] + SIDES * 6 + ["#########"] + SIDES * 7,
    "E": ["#########"] + LEFT * 6 + ["#######.."] + LEFT * 6 + ["#########"],
    "R": ["########."] + SIDES * 6 + ["########.", "#...#....", "#....#...", "#.....#..", "#......#."] + SIDES * 3,
    "S": [".#######.", "#.......#"] + LEFT * 5 + [".#######."] + RIGHT * 5 + ["#.......#", ".#######."],
    "T": ["#########"] + ["....#...."] * 14,
    "G": [".#######.", "#.......#"] + LEFT * 6 + ["#...#####"] + SIDES * 5 + [".#######."],
    "F": ["#########"] + LEFT * 6 + ["#######.."] + LEFT * 7,
}
GLYPH_W = 10  # 9 + 1 after bolding
GLYPH_GAP = 2

BIN_ICON = [
    "...###...",
    "#########",
    ".........",
    ".#######.",
    ".#.#.#.#.",
    ".#.#.#.#.",
    ".#.#.#.#.",
    ".#.#.#.#.",
    ".#.#.#.#.",
    ".#.#.#.#.",
    ".#######.",
]

def to_int(s):
    s = s.lstrip("0")
    return int(s) if s else 0

def next_pickup(dates, today, year):
    best = -1
    best_date = None
    for part in dates.replace("/", "-").split(","):
        p = part.strip().split("-")
        if len(p) != 2:
            continue
        ds = p[0].strip()
        ms = p[1].strip()
        if not ds.isdigit() or not ms.isdigit():
            continue
        dd = to_int(ds)
        mm = to_int(ms)
        if mm < 1 or mm > 12 or dd < 1 or dd > 31:
            continue
        d = time.time(year = year, month = mm, day = dd, location = TZ)
        h = (d - today).hours
        if h < -12:
            continue
        days = int((h + 12) // 24)
        if best < 0 or days < best:
            best = days
            best_date = d
    return best, best_date

def pixels(rows, x, y, color):
    # One box per horizontal run of lit pixels.
    out = []
    for r, line in enumerate(rows):
        start = -1
        for c in range(len(line) + 1):
            on = c < len(line) and line[c] == "#"
            if on and start < 0:
                start = c
            elif not on and start >= 0:
                out.append(render.Padding(pad = (x + start, y + r, 0, 0), child = render.Box(width = c - start, height = 1, color = color)))
                start = -1
    return out

def bold(rows):
    # Thicken every stroke to 2 px: a pixel is lit when it or its left/upper neighbour is.
    h = len(rows)
    w = len(rows[0])
    out = []
    for r in range(h + 1):
        line = ""
        for c in range(w + 1):
            on = False
            for dr, dc in [(0, 0), (1, 0), (0, 1), (1, 1)]:
                rr = r - dr
                cc = c - dc
                if rr >= 0 and rr < h and cc >= 0 and cc < w and rows[rr][cc] == "#":
                    on = True
            line += "#" if on else "."
        out.append(line)
    return out

def at(x, y, child):
    return render.Padding(pad = (x, y, 0, 0), child = child)

def big_name(hits):
    if len(hits) == 1 and all([ch in GLYPHS for ch in hits[0][0].elems()]):
        name, color = hits[0]
        width = len(name) * GLYPH_W + (len(name) - 1) * GLYPH_GAP
        x = (64 - width) // 2
        out = []
        for i, ch in enumerate(name.elems()):
            out.extend(pixels(bold(GLYPHS[ch]), x + i * (GLYPH_W + GLYPH_GAP), 15, color))
        return out

    # Several bins on the same day: smaller font, scrolling when it does not fit.
    pieces = []
    for i, h in enumerate(hits):
        if i > 0:
            pieces.append(render.Text("+", font = "6x13", color = WHITE))
        pieces.append(render.Text(h[0], font = "6x13", color = h[1]))
    row = render.Row(children = pieces)
    if len("+".join([h[0] for h in hits])) > 10:
        row = render.Marquee(width = 64, child = row)
    return [at(0, 16, render.Box(width = 64, height = 13, child = row))]

def screen(label, big):
    # Full-size first child pins the Stack to the 64x32 canvas so positions are absolute.
    children = [render.Box(width = 64, height = 32)]
    children.extend(pixels(BIN_ICON, 2, 2, ICON))
    children.append(at(14, 2, render.Text(label, font = "6x13", color = WHITE)))
    children.extend(big)
    return render.Root(child = render.Box(width = 64, height = 32, color = BG, child = render.Stack(children = children)))

def main(config):
    now = time.now().in_location(TZ)
    today = time.time(year = now.year, month = now.month, day = now.day, location = TZ)

    soonest = -1
    hits = []
    when = None
    for key, name, color in BINS:
        days, d = next_pickup(config.get(key, DEFAULTS[key]), today, now.year)
        if days < 0:
            continue
        if soonest < 0 or days < soonest:
            soonest = days
            hits = [(name, color)]
            when = d
        elif days == soonest:
            hits.append((name, color))

    if not hits:
        return screen("BIN DAY", [at(0, 16, render.Box(width = 64, height = 13, child = render.Text("NO DATES", font = "6x13", color = "#a8b0bc")))])

    if soonest == 0:
        label = "TODAY"
    elif soonest == 1:
        label = "TOMORROW"
    elif soonest < 7:
        label = when.format("Mon").upper() + " " + str(when.day)
    else:
        label = str(when.day) + " " + when.format("Jan").upper()

    return screen(label, big_name(hits))
