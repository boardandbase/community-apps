# Pixel Art

Shows a 64x32 picture from a link — a PNG, or an animated GIF that plays on the display. Optionally with the time on top of it.

## Setup

| Field | What to put there |
| --- | --- |
| `url` | A link to a 64x32 PNG or animated GIF |
| `clock` | `off`, `bottom-right`, `bottom-left`, `top-right`, `top-left` or `center` |
| `fps` | Frames per second for an animation, `1` to `30` |
| `timezone` | Timezone for the clock overlay |

**Or the quick way:**

```
url=https://example.com/art.png; clock=bottom-right
```

The picture is fetched once and cached. Anything that isn't 64x32 gets scaled to
fit, so it looks best if you make it the right size yourself.

Without a link the app shows a small "No art" notice.
