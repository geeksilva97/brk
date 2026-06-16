# Step 2 glue — the env adapter (the seam between "protocol, solved" and "app").
# Turns protocol-http1's parsed request into a Rack-compliant env hash.
require 'stringio'

def build_env(method:, path:, version:, authority:, headers:, body:, port:)
  path_info, query = path.split("?", 2)
  input = body ? body.join : ""

  env = {
    "REQUEST_METHOD"  => method,
    "SCRIPT_NAME"     => "",
    "PATH_INFO"       => path_info,
    "QUERY_STRING"    => query || "",
    "SERVER_PROTOCOL" => version,
    "SERVER_NAME"     => "localhost",
    "SERVER_PORT"     => port.to_s,
    "HTTP_HOST"       => authority || "localhost:#{port}",
    "rack.input"      => StringIO.new(input),
    "rack.errors"     => $stderr,
    "rack.url_scheme" => "http",
  }
  env["CONTENT_LENGTH"] = input.bytesize.to_s if body

  headers.each do |name, value|
    case name
    when "content-type"   then env["CONTENT_TYPE"]   = value
    when "content-length" then env["CONTENT_LENGTH"] = value
    else env["HTTP_#{name.upcase.tr('-', '_')}"] = value
    end
  end

  env
end
