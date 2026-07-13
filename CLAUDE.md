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
