# The client library. The plain Client below is GIVEN (Step 12 state): writes go to the leader,
# reads go to whichever node you name, with no consistency guarantee at all.
#
# Step 13 adds Client::Session here — the trial drives it through this contract:
#   session = Client::Session.new            # one user's session
#   session.write(sql)                       # a write on behalf of that user
#   session.read(sql, prefer: port)          # -> rows; should start at the preferred node
#   session.retries                          # -> Integer, total retries/redirects so far (0 if none)
# On giving up, a read raises (any StandardError) instead of returning stale rows.
require_relative "wire"

class Client
  LEADER = 7001
  FOLLOWERS = [7002, 7003].freeze

  def initialize(leader: LEADER, followers: FOLLOWERS)
    @leader = leader
    @followers = followers
  end

  def write(sql)
    reply = Wire.call(@leader, { "op" => "write", "sql" => sql })
    raise reply["error"] unless reply["ok"]

    reply
  end

  def read(sql, node:)
    reply = Wire.call(node, { "op" => "read", "sql" => sql })
    raise reply["error"] unless reply["ok"]

    reply["rows"]
  end

  def status(node)
    Wire.call(node, { "op" => "status" })
  end
end
