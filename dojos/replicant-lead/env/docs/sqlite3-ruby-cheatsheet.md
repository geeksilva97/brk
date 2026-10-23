# The `sqlite3` gem — the cheatsheet (SQLite from Ruby)

In this dojo SQLite is the **state machine**: each node keeps its own local SQLite database, and
"applying" a log entry means running its SQL against that database. You are not deriving a storage
engine — SQLite is the given black box. This is the vendored `sqlite3` gem (`/replicant:setup`
installed it into `vendor/bundle`), so **run your nodes with `bundle exec ruby …`**. `ri` for the gem
is in `docs/ri-SQLite3-Database.txt` if present.

## Open / create a database

```ruby
require "sqlite3"

db = SQLite3::Database.new("node-1.db")       # a file on disk (created if absent)
db.execute("CREATE TABLE IF NOT EXISTS kv (k TEXT PRIMARY KEY, v TEXT)")
```

## Write with bind parameters (never string-interpolate SQL)

```ruby
db.execute("INSERT INTO kv (k, v) VALUES (?, ?)", ["name", "ada"])
db.execute("UPDATE kv SET v = ? WHERE k = ?", ["lovelace", "name"])
```

`?` placeholders + an array of values. This is safe and it keeps the *exact* SQL text stable — which
matters when that SQL text is the thing you log and replicate.

## Read rows

```ruby
rows = db.execute("SELECT k, v FROM kv ORDER BY k")   # => [["name","lovelace"], ...]
one  = db.get_first_value("SELECT v FROM kv WHERE k = ?", ["name"])   # => "lovelace"
```

## Content-checksum a database (the convergence check)

Several steps ask: *do two nodes hold identical data?* The cleanest way is to hash a canonical dump.
Two equivalent options — use either:

**From the shell (simplest):**
```sh
sqlite3 node-1.db .dump | sha256sum
sqlite3 node-2.db .dump | sha256sum      # identical hash  ==  identical content
```

**From Ruby:**
```ruby
require "digest"
def db_checksum(path)
  dump = `sqlite3 #{path} .dump`          # canonical text dump of schema + rows
  Digest::SHA256.hexdigest(dump)
end
```

`.dump` emits a deterministic, ordered SQL text representation of the whole database, so equal
content ⇒ equal hash. Comparing the raw `.db` files byte-for-byte does NOT work — SQLite files can
differ in free-page layout while holding identical data.

## Notes
- One `SQLite3::Database` per node process is fine for this dojo.
- `db.execute` runs one statement. For a batch, call it per statement (that maps cleanly onto
  "apply one log entry = run one command").
- Close with `db.close` when a node shuts down.
