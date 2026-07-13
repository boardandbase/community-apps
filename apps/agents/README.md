# Claude Agents

Shows how many Claude agents are **running** (RUN) and how many are **done** (DONE)
on the 64×32 matrix. Reads the latest value from an Adafruit IO feed that a helper
(e.g. a push script) writes to.

RUN turns amber while anything is running (green at 0). DONE is green. An optional
`tokens` field is shown bottom-right, abbreviated (e.g. `3.6K`, `211M`).

## Feed value

The feed's `value` is a JSON string:

```json
{"running": 2, "done": 5, "updated": "14:32", "tokens": 3600000}
```

## Setup

Open the app's settings and fill in three things:

| Field | What to put there |
| --- | --- |
| `aio_username` | Your Adafruit IO username |
| `aio_key` | Your Adafruit IO key (io.adafruit.com → *My Key*) |
| `aio_feed` | The feed name the status is pushed to |

**Or the quick way:** paste this single line into the **Parameters** field and change
the values to your own:

```
aio_username=UserA; aio_key=aio_xxxxxxxxxxxx; aio_feed=agent
```

That's it. Your API key lives in the settings only — never in the code — so the app is
safe to share.
