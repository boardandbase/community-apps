# Countdown

Counts down to a date and time you pick, in days, hours and minutes. After the moment passes it shows how long ago it was.

## Setup

| Field | What to put there |
| --- | --- |
| `label` | What you're counting down to, e.g. `CHRISTMAS` (max 12 characters) |
| `target_date` | The date as `YYYY-MM-DD` |
| `target_time` | The time as `HH:MM` |
| `color` | `green`, `red`, `blue`, `orange`, `purple` or `white` |
| `timezone` | An IANA timezone |

**Or the quick way:**

```
label=CHRISTMAS; target_date=2026-12-25; target_time=00:00; color=red
```

Needs no internet connection and no API key. A date it can't read gives a friendly
reminder on screen instead of an error.
