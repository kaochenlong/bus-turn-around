require "json"
require "net/http"

# bin/rails external:tdx_s2s_travel_time: saves one snapshot of the stop-to-
# stop travel times TDX estimates for a Taipei bus route (the premium
# S2STravelTime API) under the data root, as
# external/tdx/<Taipei day>/S2STravelTime_<route name>.json, the response as
# it came. It serves one internal comparison with the run times of the
# derived tables (02-route-307-page); nothing on the site or in the derived
# tables reads it. The credentials are Rails credentials under tdx, the
# client_id and client_secret of a TDX application; a run without them prints
# how to add them and writes nothing, and so does a failed request.
class TdxS2sTravelTimeSnapshot
  TOKEN_URL = "https://tdx.transportdata.tw/auth/realms/TDXConnect/protocol/openid-connect/token".freeze
  API_URL = "https://tdx.transportdata.tw/api/premium/V3/Map/Estimation/Bus/S2STravelTime/City/Taipei/RouteName/%<route_name>s".freeze
  DIRECTORY = "external/tdx".freeze
  USAGE = "用法：TURNAROUND_DATA=<原始檔的資料根目錄> bin/rails external:tdx_s2s_travel_time ROUTE_NAME=307".freeze
  NO_CREDENTIALS = "沒有 TDX 憑證：用 bin/rails credentials:edit 在 tdx 底下加 client_id 與 client_secret（TDX 應用程式的憑證），" \
                   "不要把值寫進 repo 或任何檔。".freeze

  # The token or the response is not usable; the message says why.
  class Error < StandardError; end

  # The default HTTP client: a client-credentials token request and an API
  # request with headers, each returning [HTTP status, body]. Tests pass their
  # own client instead, so they never use the network.
  module Client
    def self.token(url, client_id:, client_secret:)
      response = Net::HTTP.post_form(URI(url), "grant_type" => "client_credentials", "client_id" => client_id, "client_secret" => client_secret)
      [ response.code.to_i, response.body.to_s ]
    end

    def self.get(url, headers)
      response = Net::HTTP.get_response(URI(url), headers)
      [ response.code.to_i, response.body.to_s ]
    end
  end

  # The rake task: returns the exit status.
  def self.run(env, out: $stdout, client: Client, credentials: Rails.application.credentials.tdx, day: Date.current)
    data_root, route_name = env.values_at("TURNAROUND_DATA", "ROUTE_NAME").map(&:presence)
    unless data_root && route_name
      out.puts(USAGE)
      return 1
    end
    unless credentials && credentials[:client_id].present? && credentials[:client_secret].present?
      out.puts(NO_CREDENTIALS)
      return 1
    end

    snapshot = new(data_root:, route_name:, day:, client:, credentials:)
    out.puts("#{snapshot.path}：#{snapshot.call} 個項目")
    0
  rescue Error => e
    out.puts("沒有寫入站間旅行時間快照：#{e.message}")
    1
  end

  def initialize(data_root:, route_name:, day:, client: Client, credentials: Rails.application.credentials.tdx)
    @data_root = data_root
    @route_name = route_name
    @day = day
    @client = client
    @credentials = credentials
  end

  def path = File.join(@data_root, DIRECTORY, @day.iso8601, "S2STravelTime_#{@route_name}.json")

  # Writes the response as it came and returns the number of items in it: the
  # elements of a JSON array, or 1 for a JSON object.
  def call
    status, body = @client.get(format(API_URL, route_name: @route_name), "Authorization" => "Bearer #{access_token}")
    raise Error, "站間旅行時間回應 HTTP #{status}" unless status == 200

    items = parse(body, "站間旅行時間")
    write(body)
    items.is_a?(Array) ? items.size : 1
  end

  private

  def access_token
    status, body = @client.token(TOKEN_URL, client_id: @credentials[:client_id], client_secret: @credentials[:client_secret])
    raise Error, "換 token 回應 HTTP #{status}" unless status == 200

    parse(body, "token")["access_token"].presence or raise Error, "token 回應裡沒有 access_token"
  end

  def parse(body, what)
    JSON.parse(body)
  rescue JSON::ParserError
    raise Error, "#{what}回應不是 JSON"
  end

  # Written to a temporary file first, so a failed write leaves no half file.
  def write(body)
    FileUtils.mkdir_p(File.dirname(path))
    temporary = "#{path}.partial"
    File.binwrite(temporary, body)
    File.rename(temporary, path)
  end
end
