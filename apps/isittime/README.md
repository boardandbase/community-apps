# Is It Time?

Asks whether it's time for something yet. Before the hour you picked it counts down; after it, it says YES.

## Setup

| Field | What to put there |
| --- | --- |
| `item_name` | What you're waiting for, e.g. `BEER`, `LUNCH`, `GYM` |
| `target_hour` | The hour it becomes time, `6` to `23` |
| `timezone` | An IANA timezone |

**Or the quick way:**

```
item_name=BEER; target_hour=16; timezone=Europe/Amsterdam
```

Needs no internet connection and no API key.
