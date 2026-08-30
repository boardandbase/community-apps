# ══════════════════════════════════════════════════════════════════════════════
# weather.star — MatrixOS built-in app als Pixlet/Tronbyt-app
#
# GEGENEREERD door star_apps/build.py uit src/weather.star.
# Bewerk het bronbestand, niet dit bestand:  py star_apps/build.py weather
# ══════════════════════════════════════════════════════════════════════════════
load("render.star", "render")
load("http.star", "http")
load("math.star", "math")
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


# ── net.star — HTTP-helpers voor de BYOK-apps ─────────────────────────────────

_URL_SAFE = ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz" +
             "0123456789-_.~")
_URL_HEX = "0123456789ABCDEF"


def url_quote(s):
    """Percent-encoding voor querywaarden.

    Symbolen komen uit gebruikersconfig ("XAU/USD", of erger) en gaan
    rechtstreeks een URL in; alles buiten de unreserved set wordt gecodeerd,
    zodat een symbool nooit extra parameters kan aanplakken.
    """
    ords = [o for o in s.elem_ords()]
    out = []
    for i in range(len(s)):
        ch = s[i]
        if ch in _URL_SAFE:
            out.append(ch)
        else:
            b = ords[i]
            out.append("%" + _URL_HEX[b // 16] + _URL_HEX[b % 16])
    return "".join(out)


def query(params):
    """dict -> "a=1&b=2", waarden gecodeerd, sleutels in opgegeven volgorde."""
    parts = []
    for k in params:
        parts.append(k + "=" + url_quote(str(params[k])))
    return "&".join(parts)


def get_json_result(url, ttl_seconds = 60, headers = None):
    """[statuscode, body of None].

    Voor apps die het verschil tussen "symbool bestaat niet" (404) en "te vaak
    gevraagd" (429) op het scherm willen zetten. Een nulkoers tonen bij een fout
    is misleidend: dat is niet te onderscheiden van een echte prijs van nul.
    """
    if headers == None:
        resp = http.get(url, ttl_seconds = ttl_seconds)
    else:
        resp = http.get(url, headers = headers, ttl_seconds = ttl_seconds)
    if resp.status_code != 200:
        print("HTTP %d voor %s" % (resp.status_code, url))
        return [resp.status_code, None]
    return [200, resp.json()]


def get_json(url, ttl_seconds = 60, headers = None):
    """GET + JSON, of None bij een fout. Nooit een exception: een kapotte API
    mag het scherm niet zwart maken, net als de try/except in de Python-apps."""
    return get_json_result(url, ttl_seconds, headers)[1]


def num(value, fallback = 0.0):
    """Twelve Data levert getallen als string; dit maakt er een float van."""
    if value == None:
        return fallback
    t = type(value)
    if t == "float":
        return value
    if t == "int":
        return float(value)
    if t == "string":
        if not _looks_numeric(value):
            return fallback
        return float(value)
    return fallback


_NUMERIC = "0123456789+-.eE"


def _looks_numeric(s):
    """float() laat de hele render klappen op rommel; eerst zelf kijken."""
    if len(s) == 0:
        return False
    digits = 0
    for i in range(len(s)):
        ch = s[i]
        if not ch in _NUMERIC:
            return False
        if ch >= "0" and ch <= "9":
            digits += 1
    return digits > 0


# Port van apps/weather/app.py — Open-Meteo (keyless), animatie linksboven,
# temperatuur rechts, 24-uursgrafiek onderaan.
#
# Geen BYOK nodig: Open-Meteo vraagt geen sleutel en staat bewust niet op de
# denylist van pixlet_egress.

GEOCODING_URL = "https://geocoding-api.open-meteo.com/v1/search?"
WEATHER_URL = "https://api.open-meteo.com/v1/forecast?"

SCENE_W = 18
SCENE_H = 18
INFO_X = 19
GRAPH_Y = 19

FRAMES = 100
DELAY_MS = 100

# De Python-app start met _frame = 1000 en t = _frame * refresh_interval, dus
# de animatiefase begint bij 100.0 s.
T0 = 100.0
DT = 0.1

BG_TINT = {
    "sun": [45, 22, 0],
    "moon": [3, 5, 22],
    "cloud": [8, 10, 20],
    "fog": [14, 15, 18],
    "rain": [4, 8, 28],
    "snow": [6, 9, 26],
    "thunder": [14, 4, 30],
}

TEMP_COLOR = {
    "sun": 0xFFE128,
    "moon": 0xB4C8FF,
    "cloud": 0xB9B9CD,
    "fog": 0xA5ACB4,
    "rain": 0x5AA0FF,
    "snow": 0xCDDCFF,
    "thunder": 0xC88CFF,
}

HUM_BLUE = 0x50AFFF        # (80, 175, 255)
MINMAX_GRAY = 0x828294      # (130, 130, 148)
LOC_WHITE = 0xE1E4EE        # (225, 228, 238)
GRAPH_LINE = 0x00D264       # (0, 210, 100)
GRAPH_NOW = 0xFF3C3C        # (255, 60, 60)

SUN_CORE = 0xFFE419         # (255, 228, 25)
RAIN_DROP = 0x235FE6        # (35, 95, 230)
SNOW_FLAKE = 0xE1E8FF       # (225, 232, 255)
SNOW_HALO = 0x697DC8        # (105, 125, 200)
NIGHT_BG = 0x020412         # (2, 4, 18)

# Vaste posities uit random.Random(42) / random.Random(77) in de Python-app —
# die zaadwaarden zijn hier één keer uitgerekend en ingebakken, zodat regen,
# sneeuw en sterren op exact dezelfde plek staan.
DROPS = [
    [10.870255573784023, 0.4251828387853379],
    [4.675498412275028, 3.794582548529987],
    [12.520010640788211, 11.503891286189493],
    [15.167052650982372, 1.4779601547000745],
    [7.172670934649597, 0.5065527304471958],
    [3.716845571661257, 8.591039897757161],
    [0.4511114846256816, 3.3802400616730246],
    [11.048035442251894, 9.264005170254684],
    [3.747490574691844, 10.017516625890448],
    [13.760317763523053, 0.11047891452703729],
    [13.698927281157735, 11.868369714799856],
    [5.784258780805862, 2.6431514968002863],
    [16.27262222751528, 5.722107266914655],
    [1.5766793374625143, 1.6441784061688882],
    [14.407404227906817, 10.263342533237148],
    [13.721180645664463, 12.405440373794905],
    [9.115877554729913, 16.542967987649302],
    [6.435084412542009, 9.38469073164486],
]

FLAKES = [
    [14.099879292300912, 10.514835790192183, 5.41426413512794],
    [9.814986469364955, 11.977721215653698, 0.28792309409581723],
    [3.8742706860762963, 4.919595381235822, 0.5013477770373489],
    [3.9574450681375133, 1.717024299965395, 1.7465596588451004],
    [10.806635552494804, 6.202147042491432, 2.3259156135863264],
    [3.561619523115291, 4.538622974834927, 5.8851743434174955],
    [11.01660154919209, 10.3552270963388, 1.0752958398488592],
    [12.395155565155935, 2.7778423939527825, 2.384188856380992],
    [16.82189696082212, 10.879995917519578, 3.4994184469222924],
    [11.638442266827868, 14.328482643226764, 4.875751242600024],
    [3.8938172233897745, 0.545704146368642, 1.9820499566698395],
    [4.551594891586946, 3.58670834096755, 5.924476463106915],
]

STARS = [[8, 10], [6, 7], [6, 3], [9, 15], [17, 7], [4, 17], [16, 0], [8, 0], [15, 5], [6, 16]]

BOLT = [[9, 9], [7, 12], [10, 12], [8, 15], [11, 15], [7, 17]]


def wmo_category(code):
    if code <= 1:
        return "sun"
    if code <= 3:
        return "cloud"
    if code == 45 or code == 48:
        return "fog"
    if (code >= 51 and code <= 67) or (code >= 80 and code <= 82):
        return "rain"
    if code >= 71 and code <= 77:
        return "snow"
    if code >= 95:
        return "thunder"
    return "cloud"


def fmod(a, b):
    """Python's % voor floats: het resultaat heeft het teken van b."""
    r = a - float(math.floor(a / b)) * b
    return r


def ft(v):
    """Temperatuur afronden zoals _ft(): geen "-0"."""
    r = iround(v)
    return "0" if r == 0 else str(r)


# ──────────────────────────────────────────────────────────────────────────────
# Achtergrond
# ──────────────────────────────────────────────────────────────────────────────

def build_strength():
    """De radiale afname is framen-onafhankelijk, dus één keer uitrekenen."""
    cx = float(SCENE_W) / 2.0
    cy = float(SCENE_H) / 2.0
    grid = []
    for y in range(H):
        row = []
        for x in range(W):
            d = math.hypot(float(x) - cx, float(y) - cy)
            s = 1.0 - d / 52.0
            if s < 0.0:
                s = 0.0
            row.append(math.pow(s, 1.6))
        grid.append(row)
    return grid


def background(strength, tint, pulse):
    t0 = float(tint[0])
    t1 = float(tint[1])
    t2 = float(tint[2])
    fb = []
    for y in range(H):
        srow = strength[y]
        row = []
        for x in range(W):
            s = srow[x] * pulse
            row.append(rgb(int(t0 * s), int(t1 * s), int(t2 * s)))
        fb.append(row)
    return fb


# ──────────────────────────────────────────────────────────────────────────────
# Scènes (18x18 linksboven)
# ──────────────────────────────────────────────────────────────────────────────

def draw_sun(fb, t):
    cx = 9.0
    cy = 9.0
    pulse = 3.5 + math.sin(t * 2.2) * 0.5

    for y in range(SCENE_H):
        row = fb[y]
        for x in range(SCENE_W):
            d = math.hypot(float(x) - cx, float(y) - cy)
            if d < pulse:
                row[x] = SUN_CORE
            elif d < pulse + 1.6:
                fade = 1.0 - (d - pulse) / 1.6
                row[x] = rgb(int(255.0 * fade), int(160.0 * fade), 0)

    for i in range(8):
        angle = t * 0.55 + float(i) * math.pi / 4.0
        ray_len = 4.5 + math.sin(t * 1.8 + float(i)) * 0.8
        for step in range(14):
            dist = pulse + 2.0 + float(step) * 0.4
            if dist > pulse + 2.0 + ray_len:
                break
            rx = iround(cx + math.cos(angle) * dist)
            ry = iround(cy + math.sin(angle) * dist)
            if rx >= 0 and rx < SCENE_W and ry >= 0 and ry < SCENE_H:
                fade = 1.0 - float(step) / 13.0
                if fade < 0.0:
                    fade = 0.0
                fb[ry][rx] = rgb(int(255.0 * fade), int(190.0 * fade), 0)


def draw_cloud(fb, t):
    drift = math.sin(t * 0.38) * 2.2
    clouds = [
        [9.0 + drift, 7.0, 6.0, 3.2],
        [5.0 + drift * 0.6, 13.0, 4.0, 2.6],
        [13.0 + drift * 0.5, 15.0, 3.8, 2.4],
    ]
    for c in clouds:
        cx = c[0]
        cy = c[1]
        rx = c[2]
        ry = c[3]
        for y in range(SCENE_H):
            row = fb[y]
            for x in range(SCENE_W):
                d = math.hypot((float(x) - cx) / rx, (float(y) - cy) / ry)
                if d < 1.0:
                    b = int(185.0 * (1.0 - d) + 75.0)
                    o = row[x]
                    row[x] = rgb(
                        min(255, red_of(o) + int(float(b) * 0.4)),
                        min(255, green_of(o) + int(float(b) * 0.4)),
                        min(255, blue_of(o) + int(float(b) * 0.55)),
                    )


def draw_fog(fb, t):
    for y in range(SCENE_H):
        row = fb[y]
        fy = float(y)
        for x in range(SCENE_W):
            fx = float(x)
            w = (math.sin(fx * 0.5 + t * 0.6 + fy * 0.3) * 0.35 +
                 math.sin(fx * 0.3 + t * 0.35 + fy * 0.4) * 0.25 +
                 math.sin(fx * 0.8 - t * 0.45 + fy * 0.15) * 0.20)
            wave = (w + 1.0) / 2.0
            b = int(55.0 * wave + 22.0)
            row[x] = rgb(b, b, b + 14)


def draw_rain(fb, t):
    clouds = [[9.0, 4.0, 7.0, 3.0], [4.0, 5.0, 3.5, 2.0], [14.0, 5.0, 3.5, 2.0]]
    for c in clouds:
        cx = c[0]
        cy = c[1]
        rx = c[2]
        ry = c[3]
        for y in range(10):
            row = fb[y]
            for x in range(SCENE_W):
                d = math.hypot((float(x) - cx) / rx, (float(y) - cy) / ry)
                if d < 1.0:
                    b = int(90.0 * (1.0 - d) + 45.0)
                    o = row[x]
                    row[x] = rgb(
                        min(255, red_of(o) + b // 3),
                        min(255, green_of(o) + b // 3),
                        min(255, blue_of(o) + b // 2),
                    )

    for i in range(len(DROPS)):
        ox = DROPS[i][0]
        oy_base = DROPS[i][1]
        speed = 9.0 + float(i % 5) * 2.5
        ry = int(oy_base + t * speed) % SCENE_H
        rx = int(ox)
        if rx >= 0 and rx < SCENE_W:
            for s in range(2 + i % 2):
                py = (ry + s) % SCENE_H
                if py >= 8:
                    fb[py][rx] = RAIN_DROP


def draw_snow(fb, t):
    for i in range(len(FLAKES)):
        ox = FLAKES[i][0]
        oy_base = FLAKES[i][1]
        phase = FLAKES[i][2]
        speed = 1.4 + float(i % 4) * 0.6
        fy = fmod(oy_base + t * speed, float(SCENE_H))
        fx = ox + math.sin(t * 1.2 + phase) * 2.2
        sx = iround(fx) % SCENE_W
        sy = int(fy)
        if sx >= 0 and sx < SCENE_W and sy >= 0 and sy < SCENE_H:
            fb[sy][sx] = SNOW_FLAKE
            for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
                nx = sx + d[0]
                ny = sy + d[1]
                if nx >= 0 and nx < SCENE_W and ny >= 0 and ny < SCENE_H:
                    fb[ny][nx] = SNOW_HALO


def draw_thunder(fb, t):
    clouds = [[9.0, 5.0, 7.0, 3.2], [4.0, 6.0, 3.5, 2.2], [14.0, 6.0, 3.5, 2.2]]
    for c in clouds:
        cx = c[0]
        cy = c[1]
        rx = c[2]
        ry = c[3]
        for y in range(11):
            row = fb[y]
            for x in range(SCENE_W):
                d = math.hypot((float(x) - cx) / rx, (float(y) - cy) / ry)
                if d < 1.0:
                    b = int(115.0 * (1.0 - d) + 55.0)
                    o = row[x]
                    row[x] = rgb(
                        min(255, red_of(o) + b - 15),
                        min(255, green_of(o) + b - 15),
                        min(255, blue_of(o) + b),
                    )

    flash = fmod(t, 4.0)
    if flash < 0.35:
        alpha = math.sin(flash / 0.35 * math.pi)
        iv = int(255.0 * alpha)
        c = rgb(iv, iv, int(float(iv) * 0.55))
        for b in BOLT:
            for dx in [-1, 0, 1]:
                bx = b[0] + dx
                by = b[1]
                if bx >= 0 and bx < SCENE_W and by >= 0 and by < SCENE_H:
                    fb[by][bx] = c


def draw_moon(fb, t):
    for y in range(SCENE_H):
        row = fb[y]
        for x in range(SCENE_W):
            row[x] = NIGHT_BG

    for i in range(len(STARS)):
        sx = STARS[i][0]
        sy = STARS[i][1]
        twinkle = math.sin(t * 1.8 + float(i) * 2.7) * 0.35 + 0.65
        b = int(twinkle * 170.0)
        if sx >= 0 and sx < SCENE_W and sy >= 0 and sy < SCENE_H:
            fb[sy][sx] = rgb(b, b, int(float(b) * 0.88))

    cx = 9.0
    cy = 9.0
    r_moon = 5.0
    r_shade = 4.5
    shade_dx = 2.8
    shade_dy = -1.2
    pulse = math.sin(t * 0.7) * 0.04 + 0.96

    for y in range(SCENE_H):
        row = fb[y]
        for x in range(SCENE_W):
            d = math.hypot(float(x) - cx, float(y) - cy)
            if d < r_moon + 3.0:
                glow = (1.0 - d / (r_moon + 3.0))
                if glow < 0.0:
                    glow = 0.0
                glow = glow * 0.25 * pulse
                o = row[x]
                row[x] = rgb(
                    min(255, red_of(o) + int(30.0 * glow)),
                    min(255, green_of(o) + int(40.0 * glow)),
                    min(255, blue_of(o) + int(80.0 * glow)),
                )

    for y in range(SCENE_H):
        row = fb[y]
        for x in range(SCENE_W):
            d_moon = math.hypot(float(x) - cx, float(y) - cy)
            d_shade = math.hypot(float(x) - (cx + shade_dx), float(y) - (cy + shade_dy))
            if d_moon < r_moon and d_shade >= r_shade:
                bright = 0.75 + 0.25 * (1.0 - d_moon / r_moon)
                b = int(bright * 210.0)
                row[x] = rgb(b, b, int(float(b) * 0.94))


SCENES = {
    "sun": draw_sun,
    "moon": draw_moon,
    "cloud": draw_cloud,
    "fog": draw_fog,
    "rain": draw_rain,
    "snow": draw_snow,
    "thunder": draw_thunder,
}


# ──────────────────────────────────────────────────────────────────────────────
# Grafiek, tekst en locatie
# ──────────────────────────────────────────────────────────────────────────────

def interpolate(src, n):
    if len(src) == 0:
        return [0.0 for _ in range(n)]
    if len(src) == n:
        return [v for v in src]
    out = []
    denom = n - 1
    if denom < 1:
        denom = 1
    for i in range(n):
        pos = float(i) * float(len(src) - 1) / float(denom)
        lo = int(pos)
        hi = lo + 1
        if hi > len(src) - 1:
            hi = len(src) - 1
        frac = pos - float(lo)
        out.append(src[lo] * (1.0 - frac) + src[hi] * frac)
    return out


def draw_temp_graph(fb, hourly, local_minutes):
    if len(hourly) < 2:
        return

    gw = 64
    gh = 32 - GRAPH_Y
    temps = interpolate(hourly, gw)

    min_t = temps[0]
    max_t = temps[0]
    for v in temps:
        if v < min_t:
            min_t = v
        if v > max_t:
            max_t = v
    rng = max_t - min_t
    if rng < 1.0:
        rng = 1.0

    now_i = clampi(int(float(local_minutes) / 1440.0 * float(gw - 1)), 0, gw - 1)

    for i in range(gw):
        norm = (temps[i] - min_t) / rng
        y = clampi(GRAPH_Y + int((1.0 - norm) * float(gh - 1)), GRAPH_Y, GRAPH_Y + gh - 1)

        for py in range(y + 1, GRAPH_Y + gh):
            depth = float(py - GRAPH_Y) / float(gh)
            fade = int(22.0 * (1.0 - depth))
            o = fb[py][i]
            fb[py][i] = rgb(
                min(255, red_of(o) + fade // 3),
                min(255, green_of(o) + fade + 8),
                min(255, blue_of(o) + fade * 2 + 5),
            )

        fb[y][i] = GRAPH_NOW if i == now_i else GRAPH_LINE


def draw_location(fb, city):
    loc = city.strip()
    if loc == "":
        return

    for _ in range(64):
        if fb_text_width(loc) <= 64:
            break
        loc = fb_trunc(loc, len([c for c in loc.codepoints()]) - 1)
    if loc == "":
        return

    w = fb_text_width(loc)
    x = 64 - w
    y = 32 - fb_text_height()

    plate_top = y - 2
    plate_left = max(0, x - 3)
    for py in range(plate_top, 32):
        vy = min(1.0, float(py - plate_top) / 2.0)
        row = fb[py]
        for px in range(plate_left, 64):
            hx = min(1.0, float(px - plate_left) / 12.0)
            alpha = 0.72 * hx * vy
            if alpha <= 0.0:
                continue
            o = row[px]
            row[px] = rgb(
                int(float(red_of(o)) * (1.0 - alpha)),
                int(float(green_of(o)) * (1.0 - alpha)),
                int(float(blue_of(o)) * (1.0 - alpha)),
            )

    fb_text(fb, x, y, loc, LOC_WHITE)


def draw_overlay(fb, data, cat, local_minutes, show_location, city):
    accent = TEMP_COLOR.get(cat, 0xFFFFFF)

    temp_str = ft(data["temp"]) + "C"
    fb_text(fb, INFO_X, 0, temp_str, accent)

    hum_str = str(data["humidity"]) + "%"
    hum_x = 63 - fb_text_width(hum_str)
    if hum_x >= INFO_X + fb_text_width(temp_str) + 2:
        fb_text(fb, hum_x, 0, hum_str, HUM_BLUE)

    minmax = ft(data["temp_min"]) + "/" + ft(data["temp_max"])
    fb_text(fb, 63 - fb_text_width(minmax), 9, minmax, MINMAX_GRAY)

    draw_temp_graph(fb, data["hourly"], local_minutes)

    if show_location == "on":
        draw_location(fb, city)


# ──────────────────────────────────────────────────────────────────────────────
# Data
# ──────────────────────────────────────────────────────────────────────────────

def fetch_weather(city):
    geo = get_json(GEOCODING_URL + query({"name": city, "count": 1}), ttl_seconds = 86400)
    if geo == None:
        return None
    results = geo.get("results")
    if results == None or len(results) == 0:
        return None
    lat = results[0].get("latitude")
    lon = results[0].get("longitude")

    data = get_json(WEATHER_URL + query({
        "latitude": lat,
        "longitude": lon,
        "current": "temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m",
        "daily": "temperature_2m_min,temperature_2m_max,sunrise,sunset",
        "hourly": "temperature_2m",
        "timezone": "auto",
        "forecast_days": 1,
    }), ttl_seconds = 300)
    if data == None:
        return None

    cur = data.get("current", {})
    daily = data.get("daily", {})
    hourly = data.get("hourly", {}).get("temperature_2m", [])

    mins = daily.get("temperature_2m_min", [0])
    maxs = daily.get("temperature_2m_max", [0])
    sunrises = daily.get("sunrise", [])
    sunsets = daily.get("sunset", [])

    return {
        "utc_offset": int(num(data.get("utc_offset_seconds"), 0.0)),
        "temp": num(cur.get("temperature_2m")),
        "humidity": int(num(cur.get("relative_humidity_2m"))),
        "code": int(num(cur.get("weather_code"))),
        "temp_min": num(mins[0]) if len(mins) > 0 else 0.0,
        "temp_max": num(maxs[0]) if len(maxs) > 0 else 0.0,
        "hourly": [num(v) for v in hourly],
        "sunrise": sunrises[0] if len(sunrises) > 0 else None,
        "sunset": sunsets[0] if len(sunsets) > 0 else None,
    }


def iso_epoch(s):
    """Open-Meteo levert lokale tijd zonder zone; die lezen we als UTC en
    vergelijken we met de lokale klok, precies zoals _local_now() doet."""
    if s == None or len(s) < 16:
        return None
    return time.parse_time(s[0:16], "2006-01-02T15:04", "UTC").unix


def main(config):
    city = config.get("city", "Amsterdam")
    show_location = config.get("show_location", "on")

    data = fetch_weather(city)
    if data == None:
        data = {
            "utc_offset": 0,
            "temp": 0.0,
            "humidity": 0,
            "code": 0,
            "temp_min": 0.0,
            "temp_max": 0.0,
            "hourly": [],
            "sunrise": None,
            "sunset": None,
        }

    local_epoch = time.now().unix + data["utc_offset"]
    local_minutes = (local_epoch % 86400) // 60

    cat = wmo_category(data["code"])
    if cat == "sun":
        sunrise = iso_epoch(data["sunrise"])
        sunset = iso_epoch(data["sunset"])
        if sunrise != None and sunset != None:
            if local_epoch < sunrise or local_epoch >= sunset:
                cat = "moon"

    strength = build_strength()
    tint = BG_TINT.get(cat, [8, 8, 16])
    scene = SCENES.get(cat, draw_cloud)

    # Buiten "sun" is de achtergrond framen-onafhankelijk; die maken we één keer
    # en kopiëren we per frame.
    static_bg = None
    if cat != "sun":
        static_bg = background(strength, tint, 1.0)

    colors = {}
    kids = []
    for f in range(FRAMES):
        t = T0 + float(f) * DT
        if cat == "sun":
            fb = background(strength, tint, math.sin(t * 1.8) * 0.08 + 0.92)
        else:
            fb = [list(row) for row in static_bg]

        scene(fb, t)
        draw_overlay(fb, data, cat, local_minutes, show_location, city)
        kids.append(fb_widget(fb, colors))

    return render.Root(
        delay = DELAY_MS,
        show_full_animation = True,
        child = render.Animation(children = kids),
    )


def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(id = "city", name = "City", icon = "city",
                        desc = "Plaatsnaam, bijvoorbeeld Amsterdam.", default = "Amsterdam"),
            schema.Dropdown(
                id = "show_location",
                name = "Show location",
                desc = "Zet de plaatsnaam rechtsonder in beeld.",
                icon = "locationDot",
                default = "on",
                options = [
                    schema.Option(display = "On", value = "on"),
                    schema.Option(display = "Off", value = "off"),
                ],
            ),
        ],
    )
