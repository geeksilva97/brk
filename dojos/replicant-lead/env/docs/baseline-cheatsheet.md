# The GIVEN baseline — what `workspace/` already does

Lead mode starts after the transport, write-ahead log and replication layers. That system is given
to you whole; your job starts at the first incident it can't handle.

## Shape
- **Three nodes on localhost.** Leader `7001`, followers `7002` and `7003`. Each has its own SQLite
  file and WAL under `workspace/.cluster/`. `bin/cluster start` always starts from empty state.
- **One table.** `users (id INTEGER PRIMARY KEY, name TEXT)`, seeded with `(1, 'initial')`.
- **Logical replication.** The leader appends each write's SQL to its WAL with an index (1, 2, 3…),
  applies it, then ships it to every follower in order.
- **Two numbers per node** (see `{"op":"status"}`):
  - `log_tail` — the highest index the node has **stored**
  - `applied_index` — the highest index it has **applied** to its SQLite
  A follower stores an entry when it arrives and applies it later, on a separate thread.

## Wire format (`lib/wire.rb`)
One JSON object per line over TCP. `Wire.call(port, request)` does one round trip.

| Request | Who | Reply |
|---|---|---|
| `{"op":"write","sql":...}` | leader only | `{"ok":true}` |
| `{"op":"read","sql":...}` | any node | `{"ok":true,"rows":[[...]]}` — from that node's local SQLite |
| `{"op":"status"}` | any node | `{"ok":true,"role":..,"log_tail":..,"applied_index":..}` |
| `{"op":"append","entry":{...}}` | leader → follower | internal |

Errors come back as `{"ok":false,"error":"..."}`.

## Client (`lib/client.rb`)
`Client#write(sql)`, `Client#read(sql, node:)`, `Client#status(port)`. Reads go exactly where you
point them, with no consistency guarantee. The header of `client.rb` describes the `Client::Session`
contract the trials drive.

## Fault injection (`bin/link`) — changes apply immediately
| Command | Effect |
|---|---|
| `bin/link 7002 delay 500` | each entry reaches 7002 no earlier than 500 ms after the leader wrote it |
| `bin/link 7002 apply-delay 200` | 7002 takes 200 ms to apply each entry it has stored |
| `bin/link 7002 partition on` / `off` | nothing reaches 7002 until it heals; nothing is lost |
| `bin/link reset` | clear every knob |

## Inspecting
- `bin/cluster status` — every node's role, `log_tail`, `applied_index`
- `sqlite3 workspace/.cluster/node-7002.db "SELECT * FROM users"`
- `workspace/.cluster/node-<port>.out` — each node's stdout/stderr

## Off limits
`bin/cluster`, `bin/link`, `lib/link.rb`, `lib/wire.rb` and the trials are the harness. The guard
blocks edits to them: change the system under test, never the thing measuring it.
