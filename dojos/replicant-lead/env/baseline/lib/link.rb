# GIVEN — the fault-injectable link from the leader to ONE follower.
#
# Entries are shipped in order, each one no earlier than `delay_ms` after it was enqueued. While
# `partitioned` is true nothing is shipped (entries wait, nothing is dropped). Knobs live in
# <cluster>/link/<port>.json and are re-read while waiting, so bin/link changes apply immediately.
require "json"
require_relative "wire"

class Link
  def self.config(dir, port)
    JSON.parse(File.read(File.join(dir, "#{port}.json")))
  rescue Errno::ENOENT, JSON::ParserError
    {}
  end

  def initialize(port, dir)
    @port = port
    @dir = dir
    @queue = Queue.new
    Thread.new { run }
  end

  def ship(entry)
    @queue << [now_ms, entry]
  end

  private

  def run
    loop do
      enqueued_at, entry = @queue.pop
      wait_until_due(enqueued_at)
      deliver(entry)
    end
  end

  def wait_until_due(enqueued_at)
    loop do
      c = Link.config(@dir, @port)
      left = c["partitioned"] ? 50 : enqueued_at + c.fetch("delay_ms", 0) - now_ms
      return if left <= 0
      sleep([left, 50].min / 1000.0)
    end
  end

  def deliver(entry)
    Wire.call(@port, { "op" => "append", "entry" => entry })
  rescue SystemCallError, IOError
    sleep 0.1
    retry
  end

  def now_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
end
