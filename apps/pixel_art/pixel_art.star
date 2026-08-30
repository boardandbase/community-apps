# ══════════════════════════════════════════════════════════════════════════════
# pixel_art.star — MatrixOS built-in app als Pixlet/Tronbyt-app
#
# GEGENEREERD door star_apps/build.py uit src/pixel_art.star.
# Bewerk het bronbestand, niet dit bestand:  py star_apps/build.py pixel_art
# ══════════════════════════════════════════════════════════════════════════════
load("render.star", "render")
load("encoding/base64.star", "base64")
load("http.star", "http")
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


# Port van apps/pixel_art/app.py — pixel art met optionele klok-overlay.
#
# Verschil met de Python-app: die leest het plaatje van schijf
# (apps/pixel_art/art/<device>/<bestand>). Starlark heeft geen filesystem, dus
# het beeld moet ofwel in het script zitten ofwel over HTTP komen:
#
#   1. `url` ingevuld  -> dat plaatje wordt opgehaald (PNG of animated GIF).
#   2. anders          -> de frames in FRAMES_B64 hieronder.
#   3. geen van beide  -> hetzelfde "No art"-scherm als de Python-app.
#
# Met star_apps/tools/gen_pixel_art.py bak je een bestand uit art/ rechtstreeks
# in een eigen .star, frame voor frame; dat is pixelgelijk aan de Python-app.

# Wordt gevuld door gen_pixel_art.py.
FRAMES_B64 = []

CLOCK_POSITIONS = {
    "off": None,
    "bottom-right": [27, 24],
    "bottom-left": [1, 24],
    "top-right": [27, 0],
    "top-left": [1, 0],
    "center": [14, 12],
}

PLACEHOLDER_RED = 0xFF0000
PLACEHOLDER_GRAY = 0x969696   # (150, 150, 150)


def placeholder(filename):
    fb = fb_new()
    fb_text(fb, 2, 4, "No art", PLACEHOLDER_RED)
    fb_text(fb, 2, 14, fb_trunc(filename, 10), PLACEHOLDER_GRAY)
    return fb_root(fb, delay = 30000)


def clock_overlay(position, tz):
    """Zwart plaatje achter de tijd, daarboven de tijd in wit — de rest blijft
    doorzichtig zodat het plaatje eronder zichtbaar blijft."""
    pos = CLOCK_POSITIONS.get(position)
    if pos == None:
        return None

    time_str = time.now().in_location(tz).format("15:04")
    tx = pos[0]
    ty = pos[1]
    tw = fb_text_width(time_str)

    fb = fb_new_transparent()
    fb_rect(fb, tx - 1, ty - 1, tx + tw, ty + 8, 0)
    fb_text(fb, tx, ty, time_str, 0xFFFFFF)
    return fb_widget(fb)


def main(config):
    clock = config.get("clock", "off")
    tz = config.get("timezone", "Europe/Amsterdam")
    filename = config.get("filename", "demo.png")

    fps = int(config.get("fps", "8"))
    fps = clampi(fps, 1, 30)

    url = config.get("url", "").strip()
    sources = []
    if url != "":
        resp = http.get(url, ttl_seconds = 3600)
        if resp.status_code == 200:
            sources = [resp.body()]
    elif len(FRAMES_B64) > 0:
        sources = [base64.decode(b) for b in FRAMES_B64]

    if len(sources) == 0:
        return placeholder(filename)

    overlay = clock_overlay(clock, tz)

    kids = []
    for src in sources:
        img = render.Image(src = src, width = 64, height = 32)
        if overlay == None:
            kids.append(img)
        else:
            kids.append(render.Stack(children = [img, overlay]))

    if len(kids) == 1:
        return render.Root(delay = 30000, child = kids[0])

    return render.Root(
        delay = 1000 // fps,
        show_full_animation = True,
        child = render.Animation(children = kids),
    )


def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(id = "url", name = "Image URL", icon = "image",
                        desc = "PNG of animated GIF van 64x32. Leeg = het ingebakken plaatje.",
                        default = ""),
            schema.Dropdown(
                id = "clock",
                name = "Clock overlay",
                desc = "Tijd over het plaatje heen.",
                icon = "clock",
                default = "off",
                options = [
                    schema.Option(display = "Off", value = "off"),
                    schema.Option(display = "Bottom right", value = "bottom-right"),
                    schema.Option(display = "Bottom left", value = "bottom-left"),
                    schema.Option(display = "Top right", value = "top-right"),
                    schema.Option(display = "Top left", value = "top-left"),
                    schema.Option(display = "Center", value = "center"),
                ],
            ),
            schema.Text(id = "fps", name = "FPS", icon = "gauge",
                        desc = "Frames per seconde bij een animatie (1-30).", default = "8"),
            schema.Text(id = "timezone", name = "Timezone", icon = "globe",
                        desc = "Tijdzone voor de klok-overlay.", default = "Europe/Amsterdam"),
        ],
    )
