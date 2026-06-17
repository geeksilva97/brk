# GIVEN cheatsheet — Back-of-envelope capacity estimation

> **This is GIVEN scaffolding.** The formulas and shortcuts are handed to you. Your job in the
> estimation phase is to *apply* them to ride-sharing and defend your assumptions — not to memorize
> the table.

## Powers of 2 (data sizes)
| Power | Exact | Name | Bytes |
|---|---|---|---|
| 10 | 1,024 | 1 KB | ~10^3 |
| 20 | ~1 million | 1 MB | ~10^6 |
| 30 | ~1 billion | 1 GB | ~10^9 |
| 40 | ~1 trillion | 1 TB | ~10^12 |
| 50 | ~1 quadrillion | 1 PB | ~10^15 |

## Time shortcuts
- **Seconds per day ≈ 86,400 ≈ 10^5** (the single most useful estimation shortcut — round to 100k).
- Seconds per month ≈ 2.5 million ≈ 2.5 × 10^6.
- 1 day ≈ 10^5 s, so **X per day ÷ 10^5 ≈ X per second** average.

## The core formulas
- **Average QPS** = (daily actions) ÷ 86,400 ≈ (daily actions) ÷ 10^5.
- **Peak QPS** = average QPS × a peak factor (commonly **2–10×**; state which you assume and why).
- **Storage** = (objects) × (bytes per object); add replication factor (×3 is common) and growth horizon.
- **Bandwidth** = QPS × payload size.
- **Read:write ratio** — state it (e.g. 100:1 read-heavy); it drives caching and replica decisions.

## Discipline (what interviewers grade)
1. **State assumptions out loud.** "Assume 100M daily active users, 10% take a ride/day" beats a bare number.
2. **Show the formula, then the number.** The arithmetic matters less than the reasoning.
3. **Round aggressively.** Use 10^5 for a day; nobody wants you doing long division.
4. **Sanity-check the magnitude.** Is the answer GB or PB? QPS in the hundreds or millions? Wrong
   order of magnitude is the only real failure.

## Worked shape for ride-sharing (fill in your own assumptions)
- Drivers send a GPS ping every few seconds → location-update QPS = (active drivers) ÷ (ping interval).
  This is usually the **dominant write load** and the number that should surprise you.
- Ride requests are far rarer than location pings → matching QPS is small next to ingestion QPS.
- Storage: trips are small rows but accumulate forever; raw location pings are huge but expirable.

Use these shapes to find *where the system actually hurts* — that's the point of the estimate.
