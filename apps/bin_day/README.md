# Bin Day

Shows which bin goes out next, so you never miss collection day again. At the top a small green bin with when it is — `TOMORROW`, `TODAY`, the weekday and date for this week (like `THU 29`) or just the date further ahead (like `5 NOV`). Below it, in big letters, the bin: `REST`, `GFT` or `PAPER`, each in its own colour.

If two bins are collected on the same day, both are shown in a smaller font, like `REST+PAPER`. If that doesn't fit, it scrolls.

Without any setup the app shows example dates (the 2026 calendar of Eemsdelta), so you can see what it looks like first.

## Setup

| Field | What to put there |
| --- | --- |
| `rest` | Collection dates for the general waste bin |
| `gft` | Collection dates for the green (garden and food) bin |
| `paper` | Collection dates for paper |

Write each date as `DD-MM` (day, then month) and separate them with commas, e.g. `06-01,20-01,03-02`. You'll find the dates in your municipality's waste calendar or app. A field can hold up to 200 characters — enough for a date every two weeks for a whole year — and must not contain a `;`.

**Or the quick way:**

```
rest=13-01,27-01,10-02,24-02,10-03,24-03,07-04,21-04,05-05,19-05,02-06,16-06,30-06,14-07,28-07,11-08,25-08,08-09,22-09,06-10,20-10,03-11,17-11,01-12,15-12,29-12; gft=06-01,20-01,03-02,17-02,03-03,17-03,31-03,14-04,28-04,12-05,26-05,09-06,23-06,07-07,21-07,04-08,18-08,01-09,15-09,29-09,13-10,27-10,10-11,24-11,08-12; paper=29-01,12-03,23-04,04-06,16-07,27-08,08-10,19-11,30-12
```

The dates count for the current year, in Dutch time (Europe/Amsterdam). After the last date of the year the screen says `NO DATES` until you fill in next year's calendar.

Needs no internet connection and no API key.
