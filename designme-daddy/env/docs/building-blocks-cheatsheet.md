# GIVEN cheatsheet — Distributed-systems building blocks

> **This is GIVEN scaffolding.** These are the components you assemble. You are handed *what each does
> and when to reach for it*; the design decision — which to use, where, and why — is yours.

## Edge / traffic
- **Load balancer (LB)** — spreads requests across servers; health-checks and removes dead ones. L4
  (TCP) vs L7 (HTTP, can route by path/header). Use to scale stateless services horizontally.
- **Reverse proxy / API gateway** — single entry point: auth, rate limiting, routing, TLS termination.
- **CDN** — caches static/edge content close to users. Great for assets; not for per-user live data.

## Compute
- **Stateless service** — holds no session state, so you scale it by adding identical instances behind
  an LB. The default shape for app tiers.
- **Stateful service** — owns data (a DB shard, a connection registry). Harder to scale; needs
  sharding/replication and careful failover.

## Storage
- **SQL (relational)** — strong consistency, transactions, joins, flexible queries. Reach for it when
  relationships and correctness matter (trips, payments, users). Scales vertically easily, horizontally
  with effort (sharding).
- **NoSQL key-value (e.g. DynamoDB, Cassandra)** — massive write throughput, horizontal scale, simple
  access patterns by key. Reach for it for high-volume, simple-shape data (location pings, sessions).
  Usually eventual consistency; limited/no joins.
- **In-memory cache (Redis/Memcached)** — RAM-speed reads for hot data; reduces DB load. Needs an
  eviction policy and an invalidation strategy. The first lever for read-heavy load.
- **Blob/object store (S3)** — cheap, durable storage for large immutable objects (receipts, logs).
- **Geospatial index** — see `geospatial-cheatsheet.md`. Specialized for "what's near this point."

## Messaging / async
- **Message queue / log (Kafka, SQS)** — decouples producers from consumers, absorbs bursts, enables
  async processing and fan-out. Reach for it to smooth a spiky write stream (location pings, events)
  and to avoid coupling services synchronously.
- **Pub/sub** — one event, many subscribers. For notifications and broadcasting state changes.

## Scaling techniques
- **Replication** — copies of data for read scale + failover. Leader/follower (one writer) or
  multi-leader. Followers serve reads; promotion handles leader failure. Read replicas help read-heavy
  load but add replication lag (eventual consistency).
- **Sharding / partitioning** — split data across nodes by a **partition key** so no single node holds
  everything. Choose the key to spread load evenly and keep related data together. Bad keys create
  **hot shards** (one node overloaded). Common keys: user ID, geographic region/geohash.
- **Consistent hashing** — maps keys to nodes so that adding/removing a node only remaps a small slice
  of keys (not everything). The standard way to shard a cache or KV store and rebalance gracefully.

## Cross-cutting concerns
- **CAP theorem** — under a network partition you choose **Consistency or Availability**, not both.
  Most large systems pick availability + eventual consistency for non-critical paths, strong
  consistency for money.
- **Idempotency** — make retried operations safe to repeat (idempotency keys on ride requests/payments).
- **Rate limiting** — protect the system and price tiers; usually at the gateway.

## How to use this in the interview
Name the component, say **why** it earns its place, and name the **cost** it adds (a cache adds
invalidation complexity; a queue adds latency and at-least-once delivery; sharding adds a key choice
and cross-shard query pain). Interviewers reward naming the trade-off, not just the box.
