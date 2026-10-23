# GIVEN — the system as it stands after Step 12: one leader, N followers, logical replication of
# SQL commands. Every node keeps two numbers:
#   log_tail       the highest log index it has STORED (written to its WAL)
#   applied_index  the highest log index it has APPLIED to its SQLite and can serve
# On the leader they move together. On a follower an entry is stored on arrival and applied later
# by a separate applier thread (slowed down by `apply_delay_ms` on the follower's link file).
#
# Requests (one JSON line each, see wire.rb):
#   {"op":"write","sql":...}   leader only — reply {"ok":true}
#   {"op":"read","sql":...}    any node   — reply {"ok":true,"rows":[...]}, served from local SQLite
#   {"op":"status"}            any node   — reply {"ok":true,"role":..,"log_tail":..,"applied_index":..}
#   {"op":"append","entry":{"index":..,"sql":..}}   leader -> follower, internal
require "sqlite3"
require "fileutils"
require_relative "wire"
require_relative "link"

class Node
  def initialize(port:, role:, followers:, dir:)
    @port = port
    @role = role
    @dir = dir
    @link_dir = File.join(dir, "link")
    FileUtils.mkdir_p(@link_dir)
    @db = SQLite3::Database.new(File.join(dir, "node-#{port}.db"))
    @db.execute("CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT)")
    @db.execute("INSERT OR IGNORE INTO users (id, name) VALUES (1, 'initial')")
    @db_lock = Mutex.new
    @wal = File.open(File.join(dir, "wal-#{port}.log"), "a")
    @log_lock = Mutex.new
    @log_tail = 0
    @applied_index = 0
    @apply_queue = Queue.new
    @links = followers.map { |f| Link.new(f, @link_dir) }
    Thread.new { applier } if role == "follower"
  end

  def serve
    server = TCPServer.new("127.0.0.1", @port)
    loop do
      client = server.accept
      Thread.new(client) { |sock| handle(sock) }
    end
  end

  private

  def handle(sock)
    while (req = Wire.recv_msg(sock))
      Wire.send_msg(sock, dispatch(req))
    end
  rescue StandardError => e
    Wire.send_msg(sock, { "ok" => false, "error" => e.message }) rescue nil
  ensure
    sock.close
  end

  def dispatch(req)
    case req["op"]
    when "write"  then write(req["sql"])
    when "append" then append(req["entry"])
    when "read"   then { "ok" => true, "rows" => query(req["sql"]) }
    when "status" then { "ok" => true, "role" => @role, "log_tail" => @log_tail, "applied_index" => @applied_index }
    else { "ok" => false, "error" => "unknown op #{req["op"].inspect}" }
    end
  end

  def write(sql)
    return { "ok" => false, "error" => "not the leader" } unless @role == "leader"

    @log_lock.synchronize do
      entry = { "index" => @log_tail + 1, "sql" => sql }
      persist(entry)
      @log_tail = entry["index"]
      query(sql)
      @applied_index = entry["index"]
      @links.each { |l| l.ship(entry) }
    end
    { "ok" => true }
  end

  def append(entry)
    @log_lock.synchronize do
      return { "ok" => true } if entry["index"] <= @log_tail # duplicate delivery

      persist(entry)
      @log_tail = entry["index"]
      @apply_queue << entry
    end
    { "ok" => true }
  end

  def applier
    loop do
      entry = @apply_queue.pop
      delay = Link.config(@link_dir, @port).fetch("apply_delay_ms", 0)
      sleep(delay / 1000.0) if delay.positive?
      query(entry["sql"])
      @applied_index = entry["index"]
    end
  end

  def persist(entry)
    @wal.write(JSON.generate(entry) + "\n")
    @wal.flush
    @wal.fsync
  end

  def query(sql)
    @db_lock.synchronize { @db.execute(sql) }
  end
end

if $PROGRAM_NAME == __FILE__
  args = ARGV.each_slice(2).to_h
  Node.new(
    port: Integer(args.fetch("--port")),
    role: args.fetch("--role"),
    followers: args.fetch("--followers", "").split(",").map { |p| Integer(p) },
    dir: args.fetch("--dir"),
  ).serve
end
