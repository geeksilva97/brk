# GIVEN cheatsheet — Geospatial indexing

> **This is GIVEN scaffolding** for the deep-dive phase. You are handed *how each index works and its
> trade-offs* so you don't derive the encoding from scratch. The decision — which index fits
> ride-matching and how to shard it — is yours.

## The problem
"Find all drivers within ~2 km of this rider, fast, while millions of drivers move and ping their
location every few seconds." A plain `(lat, lng)` column with a range scan is too slow: latitude and
longitude are two independent dimensions, and a B-tree indexes one. You need an index that turns 2D
proximity into something 1D-searchable.

## Geohash
- Interleaves latitude/longitude bits and base-32 encodes them into a short string (e.g. `9q8yyk`).
- **Key property:** a shared prefix ⇒ spatial proximity. `9q8yy` and `9q8yz` are neighbors.
- Longer prefix = smaller cell = finer precision. You pick a precision (cell size) for your query.
- **Search:** compute the rider's geohash prefix, look up that cell + its 8 neighbors (edge cases:
  points near a cell boundary fall in an adjacent cell — always query neighbors too).
- **Strength:** dead simple, string-prefix friendly, easy to shard by prefix, works with any KV store.
- **Weakness:** fixed grid; cell sizes jump in discrete steps; boundary handling needs the 8 neighbors.

## Quadtree
- Recursively subdivides space into 4 quadrants; a node splits only when it holds too many points.
- **Adapts to density:** dense areas (downtown) subdivide deeply; empty areas (ocean) stay coarse.
- **Search:** descend to the rider's leaf, collect points in it and adjacent leaves.
- **Strength:** handles skewed density well (cities vs countryside) — keeps each cell's count bounded.
- **Weakness:** it's a tree in memory; rebalancing as points move is more work than a flat geohash;
  sharding a tree across machines is fiddlier.

## S2 (Google S2 cells)
- Projects the sphere onto 6 cube faces, then uses a space-filling (Hilbert) curve to give every cell
  a 64-bit ID; nearby cells have nearby IDs (1D ordering of 2D space, like geohash but on a sphere).
- **Strength:** handles the globe without the lat/lng distortion geohash has near the poles; rich
  hierarchy of levels; the 1D cell IDs index and range-scan cleanly. Used by real ride-sharing systems.
- **Weakness:** more conceptual machinery; overkill if a geohash already meets your precision needs.

## Picking one (the decision that's yours)
- All three reduce 2D proximity to a key you can index/shard. Geohash = simplest; quadtree = best for
  skewed density; S2 = best at global scale with clean cell IDs.
- For ride-matching, the usual answer is **a grid of cells (geohash or S2) with the live driver set per
  cell kept in an in-memory store**, sharded by cell, refreshed by the location-ping stream. Justify
  your choice by query latency, how you'll shard, and how you'll handle dense hot cells.

## The hard part the interviewer will push on
Drivers **move**, so a driver's cell changes constantly and the index must update on every ping —
that's the write-amplification problem. Boundary queries must include neighboring cells. And a dense
downtown cell becomes a **hot shard**. Have an answer for each.
