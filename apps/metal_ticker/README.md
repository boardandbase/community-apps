# Metal Ticker

Live precious metal price with a sparkline chart. Uses your own Twelve Data key.

## Setup

| Field | What to put there |
| --- | --- |
| `symbol` | `XAUUSD` for gold, `XAGUSD` for silver |
| `apikey` | Your own API key from [twelvedata.com](https://twelvedata.com) |
| `interval` | Candle size for the chart: `1h`, `4h`, `1d`, `1w` |
| `currency` | `usd` or `eur` |

**Or the quick way:** paste this into the **Parameters** field and change the values:

```
symbol=XAUUSD; interval=1d; apikey=YOUR_KEY
```

## About the API key

The app talks to Twelve Data directly with *your* key, so nobody else's usage can
run your quota down — and yours can't affect anyone else.

The free plan gives 800 credits a day and 8 per minute. Each refresh costs **2
credits** (one call for the price, one for the chart), so pick a refresh interval
that fits:

| Refresh | Credits per day | Fits on the free plan |
| --- | --- | --- |
| 5 minutes | 576 | 1 ticker |
| 15 minutes | 192 | 4 tickers |
| 30 minutes | 96 | 8 tickers |

If the app can't reach the data it says so instead of showing a price of zero:
`bad symbol` if the symbol isn't recognised, `bad key` if the key was refused,
`API limit` if you've run out of credits for now.
