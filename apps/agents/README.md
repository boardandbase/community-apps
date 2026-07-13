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

## Configuration

| Field | Meaning |
| --- | --- |
| `aio_username` | Your Adafruit IO username |
| `aio_key` | Your Adafruit IO key (io.adafruit.com → *My Key*) |
| `aio_feed` | Feed name the status is pushed to |
| `params` | All-in-one override: `key=value; key2=value2` |

Provide them via the dashboard fields, or all at once on the CLI:

```sh
pixlet render agents.star 'params=aio_username=UserA; aio_key=aio_xxx; aio_feed=agent'
```

No API key is stored in the code — the defaults are empty, so the app is safe to share.
