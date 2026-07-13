# Board & Base — Community Apps

Community apps for the **Board & Base DeskDisplay** (MatrixOS) — a 64×32 LED matrix
display. Apps are written in [Starlark](https://github.com/bazelbuild/starlark) and
rendered with [Pixlet](https://github.com/tidbyt/pixlet), so they are compatible with
Tidbyt / Tronbyt as well.

## Layout

Each app lives in its own folder under `apps/`:

```
apps/
  <app-id>/
    <app-id>.star   # the app
    manifest.yaml   # id, name, summary, author
    README.md       # what it does + how to configure
```

## Running an app locally

```sh
pixlet render apps/agents/agents.star     # render one frame to a WebP/GIF
pixlet serve  apps/agents/agents.star     # live preview in the browser
```

Most apps take a bit of config (like an API key). Open the app's settings and fill in
the fields, or paste a single line into the **Parameters** field, e.g.:

```
aio_username=UserA; aio_key=aio_xxxxxxxxxxxx; aio_feed=agent
```

## Apps

| App | Description |
| --- | --- |
| [Claude Agents](apps/agents) | How many Claude agents are running / done, read from an Adafruit IO feed. |

## Contributing

- Keep secrets out of the code — read API keys from config/schema fields, never hardcode them.
- One app per folder, each with a `manifest.yaml` and a short `README.md`.
- Leave config defaults empty so the app is clean to share.
