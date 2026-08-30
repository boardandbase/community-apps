# Weather

Current temperature, humidity, today's low and high, and a 24-hour temperature graph. The left-hand corner animates with the weather: sun, moon, clouds, fog, rain, snow or a thunderstorm.

## Setup

| Field | What to put there |
| --- | --- |
| `city` | A city name, e.g. `Amsterdam`, `London`, `New York` |
| `show_location` | `on` or `off` — the city name bottom-right |

**Or the quick way:**

```
city=Amsterdam; show_location=on
```

**No API key needed.** Weather comes from [Open-Meteo](https://open-meteo.com),
which is free and keyless. The city is looked up once and then the forecast is
fetched; both are cached.

The animation follows the WMO weather code, and on a clear night the sun becomes a
waxing moon with twinkling stars.
