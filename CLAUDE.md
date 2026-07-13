# Community apps — development notes

## Testing an app locally

Pixlet is at `C:\Users\Martijn\Desktop\pixelart\pixlet.exe` (not on PATH).

The usage app fetches its JSON over HTTP, so serve a mock file and render:

```
python -m http.server 8123 --directory <dir with mock.json>
pixlet render apps/usage/claudeusage.star "api_url=http://127.0.0.1:8123/mock.json" name=Martijn timezone=Europe/Amsterdam --magnify 8 -o out.webp
```

- Mock JSON format: see apps/usage/README.md ("The data"). Build the timestamps
  relative to "now" (`reset_at` in the future, history inside the 5-hour window),
  otherwise the window filter drops the points.
- The output webp is animated (12 frames). Reading it shows frame 0; to inspect
  another frame (e.g. the blink-off state of the 100% warning icon):
  `python -c "from PIL import Image; im=Image.open('out.webp'); im.seek(8); im.convert('RGB').save('f8.png')"`

## Interactive browser preview

`pixlet serve` gives a live preview with a settings form (all schema fields,
including the `show_history` toggle). Add a `claudeusage-preview` entry to
`.claude/launch.json` (pixlet serve on port 8080; the file is git-ignored, so
recreate it per machine), start it with the `/run` skill or the preview tooling,
then set the **Data URL** field to one of the served mocks to switch state without
editing anything:

- `http://127.0.0.1:8123/full.json`   → 100% (red 100%, blinking triangle, frozen clock)
- `http://127.0.0.1:8123/normal.json` → 62%
- `http://127.0.0.1:8123/ok.json`     → 30% (green "OK")

Generate those mocks with `scratchpad/gen_mocks.py` (writes fresh timestamps each
run) and keep the `python -m http.server 8123` from above serving them.
