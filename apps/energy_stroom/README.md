# Dutch Energy Price

Today's electricity price per hour from Enever.nl, with a graph of the whole day and a red dot on the current hour. Optionally for a specific supplier, including VAT and surcharges.

## Setup

| Field | What to put there |
| --- | --- |
| `token` | Your free token from [enever.nl](https://enever.nl/prijzenfeeds/) |
| `supplier` | A supplier code, or leave empty for the bare spot price |
| `show_minmax` | `on` or `off` — the day's low and high at the bottom |
| `timezone` | Defaults to `Europe/Amsterdam` |

**Or the quick way:**

```
token=YOUR_TOKEN; supplier=TI; show_minmax=on
```

Supplier codes include `AA`, `ANWB`, `BE`, `CB`, `EE`, `EN`, `EZ`, `FR`, `TI`,
`VDB`, `VF`, `ZP` and more. Leave it empty for the raw spot price without VAT.

## About the token

Enever hands out free tokens but caps how often you may ask, **per month**, and the
counter resets on the 1st. Prices only change once an hour, so set the refresh to an
hour or more — there is nothing to gain from asking more often.

If the token runs out the app says `No data / API limit` rather than showing a wrong
price.
