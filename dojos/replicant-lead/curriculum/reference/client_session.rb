# Reference for Step 13 — ONE defensible set of decisions, for /replicant-lead:reveal and for the
# instructor. Not the answer key: a learner's different decisions are fine if they hold up in the
# trial and in the questions. Decisions this reference makes:
#   read frontier       the follower's applied_index (never log_tail)
#   write reply         the leader returns the index it assigned
#   behind node         refuses with not_caught_up; the client waits and retries the same node
#   retry policy        every 25 ms, up to 1.5 s, then falls back to the leader once
#   watermark scope     per session, the highest index this session has written
#   guarantee boundary  read-your-writes for this session only; other sessions may read stale
#
# Applying it needs two changes outside this file (node.rb):
#   write:  { "ok" => true, "index" => entry["index"] }
#   read:   honor req["min_index"] — when @applied_index < min_index, reply
#           { "ok" => false, "error" => "not_caught_up", "applied_index" => @applied_index }
class Client
  class NotCaughtUp < StandardError; end

  def read_at(sql, node:, min_index:)
    reply = Wire.call(node, { "op" => "read", "sql" => sql, "min_index" => min_index })
    raise NotCaughtUp if reply["error"] == "not_caught_up"
    raise reply["error"] unless reply["ok"]

    reply["rows"]
  end

  class Session
    RETRY_EVERY = 0.025
    GIVE_UP_AFTER = 1.5

    attr_reader :retries

    def initialize(client = Client.new)
      @client = client
      @watermark = 0
      @retries = 0
    end

    def write(sql)
      reply = @client.write(sql)
      @watermark = [@watermark, reply.fetch("index")].max
      reply
    end

    def read(sql, prefer:)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + GIVE_UP_AFTER
      begin
        @client.read_at(sql, node: prefer, min_index: @watermark)
      rescue NotCaughtUp
        @retries += 1
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
          sleep RETRY_EVERY
          retry
        end
        @client.read_at(sql, node: Client::LEADER, min_index: @watermark)
      end
    end
  end
end
