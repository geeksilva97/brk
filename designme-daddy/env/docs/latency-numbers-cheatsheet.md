# GIVEN cheatsheet — Latency numbers every engineer should know

> **This is GIVEN scaffolding.** You are handed these numbers so you can reason about bottlenecks
> without memorizing them. Quote them; don't derive them. The *decisions* (where the bottleneck is,
> what to cache, what to replicate) are yours.

## Orders of magnitude (rounded, ~2020s commodity hardware)

| Operation | Time | In nanoseconds |
|---|---|---|
| L1 cache reference | ~1 ns | 1 |
| Branch mispredict | ~3 ns | 3 |
| L2 cache reference | ~4 ns | 4 |
| Mutex lock/unlock | ~17 ns | 17 |
| Main memory (RAM) reference | ~100 ns | 100 |
| Compress 1 KB (fast) | ~2 µs | 2,000 |
| Read 1 MB sequentially from RAM | ~3 µs | 3,000 |
| SSD random read | ~16 µs | 16,000 |
| Read 1 MB sequentially from SSD | ~50 µs | 50,000 |
| Round trip within same datacenter | ~500 µs | 500,000 |
| Read 1 MB sequentially from disk (HDD) | ~1–5 ms | 1–5,000,000 |
| Disk (HDD) seek | ~5–10 ms | ~10,000,000 |
| Round trip CA ↔ Netherlands | ~150 ms | 150,000,000 |

## The shape that matters more than the exact numbers
- **Memory is ~100× faster than SSD; SSD is ~100× faster than a disk seek; a cross-continent round
  trip dwarfs everything local.** This is why caching in RAM and keeping data in the same region wins.
- **Sequential >> random** on every storage tier. Batching and sequential writes (append-only logs)
  beat scattered random writes.
- **The network is the tax.** A same-datacenter round trip (~0.5 ms) is cheap; a cross-region round
  trip (~150 ms) is a user-visible latency budget all by itself.

## Throughput rules of thumb
- A single modern server handles **~10k–100k simple requests/sec** depending on work per request.
- A single RAM-backed cache (Redis) node: **~100k+ ops/sec**.
- Disk sequential write: **hundreds of MB/sec**; this caps how fast one node ingests a write stream.

## How to use this in the interview
- In **estimation**: turn QPS and payload sizes into RAM/disk/network pressure.
- In **deep dive / scaling**: justify a cache ("RAM read is 100 ns vs an SSD read at 16 µs — caching
  the hot driver index saves ~100×"), justify regional placement, justify append-only writes.
