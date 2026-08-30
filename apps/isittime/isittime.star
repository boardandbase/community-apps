# ══════════════════════════════════════════════════════════════════════════════
# isittime.star — MatrixOS built-in app als Pixlet/Tronbyt-app
#
# GEGENEREERD door star_apps/build.py uit src/isittime.star.
# Bewerk het bronbestand, niet dit bestand:  py star_apps/build.py isittime
# ══════════════════════════════════════════════════════════════════════════════
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

# ══════════════════════════════════════════════════════════════════════════════
# fb.star — gedeelde render-laag voor de MatrixOS .star-apps
#
# GEGENEREERD door star_apps/tools/gen_fb.py — niet met de hand aanpassen.
#
# Waarom een eigen framebuffer in plaats van render.Text: de Python-apps tekenen
# met de Adafruit_GFX 5x8 bitmapfont en zetten losse pixels. Pixlet's ingebouwde
# fonts hebben andere glyphs, dus een port met render.Text zou er nét anders
# uitzien. Deze laag zet een 64x32 pixelbuffer op en comprimeert die per rij tot
# Box-widgets (run-length), zodat het eindbeeld pixel-voor-pixel gelijk is.
# ══════════════════════════════════════════════════════════════════════════════

W = 64
H = 32

# ── Adafruit_GFX classic 5x8 font (256 glyphs x 5 kolombytes, LSB = bovenste pixel)
_FONT_HEX = (
    "00000000003e5b4f5b3e3e6b4f6b3e1c3e7c3e1c183c7e3c181c577d571c1c5e7f5e1c00183c1800ffe7c3e7ff0018241800" +
    "ffe7dbe7ff30483a060e2629792926407f050507407f05253f5a3ce73c5a7f3e1c1c08081c1c3e7f14227f22145f5f005f5f" +
    "06097f017f006689956a606060606094a2ffa29408047e040810207e201008082a1c08081c2a08081e101010100c1e0c1e0c" +
    "30383e3830060e3e0e06000000000000005f00000007000700147f147f14242a7f2a12231308646236495620500008070300" +
    "001c2241000041221c002a1c7f1c2a08083e080800807030000808080808000060600020100804023e5149453e00427f4000" +
    "72494949462141494d331814127f1027454545393c4a49493141211109073649494936464949291e00001400000040340000" +
    "00081422411414141414004122140802015909063e415d594e7c1211127c7f494949363e414141227f4141413e7f49494941" +
    "7f090909013e414151737f0808087f00417f41002040413f017f081422417f404040407f021c027f7f0408107f3e4141413e" +
    "7f090909063e4151215e7f09192946264949493203017f01033f4040403f1f2040201f3f4038403f63140814630304780403" +
    "6159494d43007f4141410204081020004141417f04020102044040404040000307080020545478407f284444383844444428" +
    "384444287f385454541800087e090218a4a49c787f0804047800447d40002040403d007f1028440000417f40007c04780478" +
    "7c080404783844444438fc1824241818242418fc7c08040408485454542404043f44243c4040207c1c2040201c3c4030403c" +
    "44281028444c9090907c4464544c4400083641000000770000004136080002010204023c2623263c1ea1a161123a4040207a" +
    "385454555921555579412254547842215554784020545579400c1e5272123955555559395454545939555454580000457c41" +
    "0002457d420001457c407d1211127df0282528f07c545545002054547c547c0a097f4932494949323a4444443a324a484830" +
    "3a4141217a3a42402078009da0a07d3d4242423d3d4040403d3c24ff2424487e4943662b2ffc2f2bff0929f620c0887e0903" +
    "20545479410000447d413048484a32384040227a007a0a0a727d0d19317d2629292f28262929292630484d40203808080808" +
    "08080808382f10c8acba2f102834fa00007b000008142a142222142a14085500550055aa55aa55aaff55ff55ff000000ff00" +
    "101010ff00141414ff001010ff00ff1010f010f0141414fc001414f700ff0000ff00ff1414f404fc141417101f10101f101f" +
    "1414141f00101010f0000000001f101010101f10101010f010000000ff101010101010101010ff10000000ff140000ff00ff" +
    "00001f10170000fc04f414141710171414f404f40000ff00f714141414141414f700f7141414171410101f101f141414f414" +
    "1010f010f000001f101f0000001f14000000fc140000f010f01010ff10ff141414ff141010101f00000000f010ffffffffff" +
    "f0f0f0f0f0ffffff0000000000ffff0f0f0f0f0f3844443844fc4a4a4a347e02020606027e027e0263554941633844443c04" +
    "407e201e2006027e020299a5e7a5991c2a492a1c4c7201724c304a4d4d303048784830bc625a463d3e494949007e0101017e" +
    "2a2a2a2a2a44445f444440514a444040444a51400000ff0103e080ff000008086b6b083612362436060f090f060000181800" +
    "00001010003040ff0101001f01011e00191d1712003c3c3c3c0000000000"
)

# Glyphs voor unicode-tekens buiten de 256-tabel, gesleuteld op codepoint.
_CUSTOM = {
    8364: [0x1E, 0x2D, 0x2D, 0x21, 0x00],  # '€'
}

_HEXD = {
    "0": 0, "1": 1, "2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7,
    "8": 8, "9": 9, "a": 10, "b": 11, "c": 12, "d": 13, "e": 14, "f": 15,
}
_HX = "0123456789abcdef"

CHAR_WIDTH = 5
CHAR_HEIGHT = 8
CHAR_SPACING = 1
CHAR_ADVANCE = CHAR_WIDTH + CHAR_SPACING


def _byte_at(j):
    return _HEXD[_FONT_HEX[j]] * 16 + _HEXD[_FONT_HEX[j + 1]]


def _build_glyphs():
    g = []
    for i in range(256):
        b = i * 10
        g.append([
            _byte_at(b),
            _byte_at(b + 2),
            _byte_at(b + 4),
            _byte_at(b + 6),
            _byte_at(b + 8),
        ])
    return g


_GLYPHS = _build_glyphs()


def fb_glyph_for(codepoint):
    """Kolombytes voor een codepoint. Spiegelt `ord(char) & 0xFF` uit bitmap_font."""
    custom = _CUSTOM.get(codepoint)
    if custom != None:
        return custom
    return _GLYPHS[codepoint % 256]


# ──────────────────────────────────────────────────────────────────────────────
# Kleuren — een kleur is een int 0xRRGGBB. Dat is sneller dan tuples of strings
# en laat vergelijken (voor run-length) op één int-vergelijking neerkomen.
# ──────────────────────────────────────────────────────────────────────────────

def rgb(r, g, b):
    return (r * 65536) + (g * 256) + b


def clamp8(v):
    if v < 0:
        return 0
    if v > 255:
        return 255
    return v


def rgb_clamped(r, g, b):
    return (clamp8(int(r)) * 65536) + (clamp8(int(g)) * 256) + clamp8(int(b))


def red_of(c):
    return (c // 65536) % 256


def green_of(c):
    return (c // 256) % 256


def blue_of(c):
    return c % 256


BLACK = 0
WHITE = 0xFFFFFF

def hexcolor(c):
    """0xRRGGBB -> "#rrggbb". Geen module-cache: Starlark bevriest globals."""
    r = (c // 65536) % 256
    g = (c // 256) % 256
    b = c % 256
    return ("#" + _HX[r // 16] + _HX[r % 16] + _HX[g // 16] + _HX[g % 16] +
            _HX[b // 16] + _HX[b % 16])


# ──────────────────────────────────────────────────────────────────────────────
# Framebuffer
# ──────────────────────────────────────────────────────────────────────────────

# Een pixel met deze waarde wordt géén Box met kleur maar een lege Box: wat
# eronder ligt blijft zichtbaar. Nodig voor overlays in een render.Stack.
TRANSPARENT = -1


def fb_new():
    """Leeg 64x32 buffer (zwart)."""
    return [[0 for _ in range(W)] for _ in range(H)]


def fb_new_transparent():
    """Leeg 64x32 buffer waar niets is ingevuld — voor overlays."""
    return [[TRANSPARENT for _ in range(W)] for _ in range(H)]


def fb_fill(fb, c):
    for y in range(H):
        row = fb[y]
        for x in range(W):
            row[x] = c


def fb_pset(fb, x, y, c):
    """Pixel zetten met randcontrole (equivalent van de clip in de Python-apps)."""
    if x >= 0 and x < W and y >= 0 and y < H:
        fb[y][x] = c


def fb_pget(fb, x, y):
    if x >= 0 and x < W and y >= 0 and y < H:
        return fb[y][x]
    return 0


def fb_hline(fb, x0, x1, y, c):
    if y < 0 or y >= H:
        return
    row = fb[y]
    lo = max(0, x0)
    hi = min(W - 1, x1)
    for x in range(lo, hi + 1):
        row[x] = c


def fb_vline(fb, x, y0, y1, c):
    if x < 0 or x >= W:
        return
    for y in range(max(0, y0), min(H - 1, y1) + 1):
        fb[y][x] = c


def fb_rect(fb, x0, y0, x1, y1, c):
    """Gevulde rechthoek, inclusief eindpunten (net als PIL's draw.rectangle)."""
    for y in range(max(0, y0), min(H - 1, y1) + 1):
        row = fb[y]
        for x in range(max(0, x0), min(W - 1, x1) + 1):
            row[x] = c


def fb_blit(fb, x0, y0, rows, colors):
    """Teken een sprite uit een lijst strings; `colors` mapt teken -> kleur.

    Tekens die niet in `colors` staan (typisch '.' of '0') blijven leeg.
    """
    for dy in range(len(rows)):
        line = rows[dy]
        py = y0 + dy
        if py < 0 or py >= H:
            continue
        row = fb[py]
        for dx in range(len(line)):
            c = colors.get(line[dx])
            if c == None:
                continue
            px = x0 + dx
            if px >= 0 and px < W:
                row[px] = c


# ──────────────────────────────────────────────────────────────────────────────
# Tekst — pixelidentiek aan bitmap_font.BitmapFont (scale 1)
# ──────────────────────────────────────────────────────────────────────────────

def fb_text_width(s):
    n = len(fb_codepoints(s))
    if n == 0:
        return 0
    return n * CHAR_ADVANCE - CHAR_SPACING


def fb_text_height():
    return CHAR_HEIGHT


def fb_codepoints(s):
    return [o for o in s.codepoint_ords()]


def fb_trunc(s, n):
    """s[:n] maar op tekens in plaats van bytes — Python snijdt ook op tekens."""
    chars = [c for c in s.codepoints()]
    if len(chars) <= n:
        return s
    return "".join(chars[:n])


_POW2 = [1, 2, 4, 8, 16, 32, 64, 128]

# Kolombyte -> 8 booleans (bit 0 = bovenste pixel), vooraf uitgerekend.
_BITS = [[(cb // _POW2[r]) % 2 == 1 for r in range(CHAR_HEIGHT)] for cb in range(256)]


def fb_char(fb, x, y, codepoint, color, bg = None):
    """Eén glyph tekenen. Returnt de x voor het volgende teken.

    Spiegelt BitmapFont.draw_char (scale 1): buiten het scherm wordt geclipt,
    en met `bg` wordt ook de 1px spatiekolom gevuld.
    """
    cols = fb_glyph_for(codepoint)
    for col in range(CHAR_WIDTH):
        px = x + col
        if px < 0 or px >= W:
            continue
        bits = _BITS[cols[col]]
        for row in range(CHAR_HEIGHT):
            py = y + row
            if py < 0 or py >= H:
                continue
            if bits[row]:
                fb[py][px] = color
            elif bg != None:
                fb[py][px] = bg
    if bg != None:
        px = x + CHAR_WIDTH
        if px >= 0 and px < W:
            for row in range(CHAR_HEIGHT):
                py = y + row
                if py >= 0 and py < H:
                    fb[py][px] = bg
    return x + CHAR_ADVANCE


def fb_text(fb, x, y, s, color, bg = None):
    """Tekst tekenen. Returnt de x-positie na het laatste teken."""
    cx = x
    for cp in s.codepoint_ords():
        cx = fb_char(fb, cx, y, cp, color, bg)
    return cx


def fb_text_outlined(fb, x, y, s, color, outline = 0):
    """Tekst met 1px outline in vier richtingen — zoals de tickers doen."""
    for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
        fb_text(fb, x + d[0], y + d[1], s, outline)
    return fb_text(fb, x, y, s, color)


# ──────────────────────────────────────────────────────────────────────────────
# Naar widgets
# ──────────────────────────────────────────────────────────────────────────────

def fb_widget(fb, cache = None):
    """Framebuffer -> widgetboom. Per rij run-length gecodeerd naar Box-widgets.

    `cache` is een lokale dict kleur->hexstring; geef bij animaties dezelfde dict
    aan elk frame mee zodat de conversie maar één keer per kleur gebeurt.
    """
    if cache == None:
        cache = {}
    rows = []
    for y in range(H):
        r = fb[y]
        cells = []
        run_c = r[0]
        run_w = 1
        for x in range(1, W):
            c = r[x]
            if c == run_c:
                run_w += 1
            else:
                cells.append(_cell(run_c, run_w, cache))
                run_c = c
                run_w = 1
        cells.append(_cell(run_c, run_w, cache))
        rows.append(render.Row(children = cells))
    return render.Column(children = rows)


def _cell(c, w, cache):
    if c == TRANSPARENT:
        return render.Box(width = w, height = 1)
    h = cache.get(c)
    if h == None:
        h = hexcolor(c)
        cache[c] = h
    return render.Box(width = w, height = 1, color = h)


def fb_root(fb, delay = 5000, max_age = None):
    """Eén stilstaand beeld."""
    if max_age == None:
        return render.Root(delay = delay, child = fb_widget(fb))
    return render.Root(delay = delay, max_age = max_age, child = fb_widget(fb))


def fb_animation(frames, delay, max_age = None):
    """Lijst framebuffers -> geanimeerde root. `delay` in milliseconden per frame."""
    cache = {}
    kids = [fb_widget(f, cache) for f in frames]
    if max_age == None:
        return render.Root(
            delay = delay,
            show_full_animation = True,
            child = render.Animation(children = kids),
        )
    return render.Root(
        delay = delay,
        max_age = max_age,
        show_full_animation = True,
        child = render.Animation(children = kids),
    )


# ──────────────────────────────────────────────────────────────────────────────
# Kleine helpers die de Python-apps ook gebruiken
# ──────────────────────────────────────────────────────────────────────────────

def clampi(v, lo, hi):
    if v < lo:
        return lo
    if v > hi:
        return hi
    return v


def ifloor(v):
    """int() kapt in Python richting nul af; voor negatieve floats wil je floor."""
    i = int(v)
    if float(i) > v:
        return i - 1
    return i


def iround(v):
    """Python's round() is banker's rounding; deze helper spiegelt dat gedrag."""
    f = ifloor(v)
    frac = v - float(f)
    if frac > 0.5:
        return f + 1
    if frac < 0.5:
        return f
    if f % 2 == 0:
        return f
    return f + 1


# ── fmt.star — getalopmaak die Python's f-strings nabootst ────────────────────
#
# Starlark's %-operator kent geen precisievlaggen ("%.2f" geeft "unknown
# conversion"), terwijl de Python-apps overal f"{x:.2f}" en f"{n:02d}" gebruiken.
#
# Naïef afronden via x * 100 werkt niet: 52.905 * 100 wordt in drijvende komma
# 5290.4999999, terwijl de dubbele achter 52.905 in werkelijkheid nét bóven
# 52.905 ligt — Python drukt "52.91" af, de naïeve route "52.90". Daarom werken
# deze helpers op de decimale representatie (str(), kortste round-trip) en wordt
# een echte gelijkspel-situatie beslecht door de twee kandidaten terug te parsen
# en te kijken welke dichter bij het origineel ligt. Dat geeft exact hetzelfde
# resultaat als Python, inclusief afronden-naar-even bij een echte helft.

_POW10 = [1, 10, 100, 1000, 10000, 100000, 1000000]


def pad2(n):
    """f"{n:02d}" voor n >= 0."""
    if n < 10:
        return "0" + str(n)
    return str(n)


def zpad(s, width):
    if len(s) >= width:
        return s
    return ("0" * (width - len(s))) + s


def abs_f(x):
    return -x if x < 0 else x


def _compose(n, decimals):
    """Geheel getal n als decimale string met `decimals` cijfers achter de komma."""
    t = str(n)
    if decimals == 0:
        return t
    t = zpad(t, decimals + 1)
    cut = len(t) - decimals
    return t[0:cut] + "." + t[cut:]


def _resolve_tie(v, n, decimals):
    """De decimale weergave zit precies op de helft; de échte dubbele beslist."""
    down = float(_compose(n, decimals))
    up = float(_compose(n + 1, decimals))
    d1 = v - down
    d2 = up - v
    if d1 < d2:
        return False
    if d1 > d2:
        return True
    return n % 2 == 1  # gelijkspel -> naar even


def _fixed_scaled(v, decimals):
    """Terugvaloptie voor waarden die str() in e-notatie zet."""
    scale = _POW10[decimals]
    n = int(v * float(scale) + 0.5)
    return _compose(n, decimals)


def fixed(x, decimals):
    """f"{x:.Nf}"."""
    neg = x < 0
    v = -x if neg else x

    s = str(v)
    if s.find("e") >= 0 or s.find("E") >= 0 or s.find("I") >= 0 or s.find("N") >= 0:
        out = _fixed_scaled(v, decimals)
        return ("-" + out) if neg else out

    dot = s.find(".")
    if dot < 0:
        ip = s
        fp = ""
    else:
        ip = s[0:dot]
        fp = s[dot + 1:]

    if len(fp) <= decimals:
        out = ip
        if decimals > 0:
            out = out + "." + fp + ("0" * (decimals - len(fp)))
        return ("-" + out) if neg else out

    keep = fp[0:decimals]
    rest = fp[decimals:]
    n = int(ip + keep)

    first = rest[0]
    if first > "5":
        round_up = True
    elif first < "5":
        round_up = False
    else:
        tail_nonzero = False
        for i in range(1, len(rest)):
            if rest[i] != "0":
                tail_nonzero = True
                break
        round_up = True if tail_nonzero else _resolve_tie(v, n, decimals)

    if round_up:
        n += 1

    out = _compose(n, decimals)
    return ("-" + out) if neg else out


def signed_fixed(x, decimals):
    """f"{x:+.Nf}" — altijd een teken ervoor."""
    s = fixed(x, decimals)
    if s.startswith("-"):
        return s
    return "+" + s


# Port van apps/is_it_time/app.py (IsItTimeApp) — dagelijkse "is it time for X?".

HEADER_GRAY = 0x787878   # (120, 120, 120)
SUB_GRAY = 0x646464      # (100, 100, 100)
ITEM_WHITE = 0xFFFFFF
YES_GREEN = 0x00FF00
ENJOY_BLUE = 0x0096FF
NO_RED = 0xFF0000


def main(config):
    item = config.get("item_name", "BEER").upper()
    tz = config.get("timezone", "Europe/Amsterdam")
    target_hour = int(config.get("target_hour", "16"))

    now = time.now().in_location(tz)
    target = time.time(
        year = now.year,
        month = now.month,
        day = now.day,
        hour = target_hour,
        minute = 0,
        second = 0,
        location = tz,
    )
    remaining = int((target - now).seconds)
    is_it_time = remaining <= 0

    fb = fb_new()

    # Rij 1: vraag
    fb_text(fb, 2, 1, "TIME FOR", HEADER_GRAY)

    # Rij 2: item
    fb_text(fb, 2, 9, item + "?", ITEM_WHITE)

    if is_it_time:
        fb_text(fb, 2, 17, "YES!", YES_GREEN)
        fb_text(fb, 2, 25, "ENJOY!", ENJOY_BLUE)
    else:
        hours = remaining // 3600
        minutes = (remaining % 3600) // 60
        if hours > 0:
            countdown = str(hours) + "h " + pad2(minutes) + "m"
        else:
            countdown = str(minutes) + "m"
        fb_text(fb, 2, 17, "NOT YET", NO_RED)
        fb_text(fb, 2, 25, countdown, SUB_GRAY)

    return fb_root(fb, delay = 60000)


def get_schema():
    hours = [schema.Option(display = str(h) + ":00", value = str(h)) for h in range(6, 24)]
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(id = "item_name", name = "Item", icon = "beerMugEmpty",
                        desc = "Waar wacht je op?", default = "BEER"),
            schema.Dropdown(id = "target_hour", name = "Time (hour)", icon = "clock",
                            desc = "Vanaf welk uur is het zover?",
                            default = "16", options = hours),
            schema.Text(id = "timezone", name = "Timezone", icon = "globe",
                        desc = "IANA-tijdzone.", default = "Europe/Amsterdam"),
        ],
    )
