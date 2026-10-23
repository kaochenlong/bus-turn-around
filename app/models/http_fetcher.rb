require "net/http"

# The default fetcher of the external snapshots (bin/rails external:*): fetches
# a URL and returns [HTTP status, body bytes], following up to three redirects.
# Tests pass their own fetcher instead, so they never use the network.
module HttpFetcher
  MAX_REDIRECTS = 3

  def self.call(url, redirects_left = MAX_REDIRECTS)
    response = Net::HTTP.get_response(URI(url))
    if response.is_a?(Net::HTTPRedirection) && redirects_left.positive?
      call(response["location"], redirects_left - 1)
    else
      [ response.code.to_i, response.body.to_s ]
    end
  end
end
