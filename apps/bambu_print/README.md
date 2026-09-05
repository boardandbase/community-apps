# Bambu Print Progress

Shows what your Bambu Lab printer is doing right now, read from Bambu Cloud: the job name, a big percentage, the time left and a progress bar along the bottom. A pulsing dot in the corner shows the state — green while printing, orange when paused, blue when done, red when failed or offline.

Progress is worked out from the elapsed time against the printer's own estimate, so it needs no local network access to the printer. Made for the P1S, but it works with any printer that shows up in your Bambu Cloud account.

Without a token the app shows demo data, so you can see what it looks like before you set it up.

## Setup

| Field | What to put there |
| --- | --- |
| `access_token` | Your Bambu Cloud access token (see below) |
| `access_token_2` … `access_token_5` | Optional — if the token is too long for one box, split it over these; they are joined in order |
| `printer_name` | Optional — the name of the printer as shown in Bambu Handy/Studio. Leave empty to use the first printer on your account |

**Or the quick way:**

```
access_token=YOUR_TOKEN; printer_name=P1S
```

Set the refresh to a minute or more — the cloud data is cached for 60 seconds anyway.

## About the token

The app talks to the Bambu Cloud with the same Bearer token the Bambu Handy app and Bambu Studio use. There is no public "create API key" page; you get the token by logging in to your Bambu account through the cloud login and copying the `accessToken` from the response. Tokens are long (often over 1000 characters) and expire after a few months, so if the app starts saying `NO CLOUD` you most likely need a fresh one.

If you are on the Chinese cloud, change `API_BASE` at the top of the file to `https://api.bambulab.cn`.

The app makes at most two requests per refresh: one to list your printers and one for the current job.
