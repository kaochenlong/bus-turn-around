require "rails_helper"

RSpec.describe HttpFetcher, type: :model do
  let(:requested) { [] }

  def url(name) = "https://example.test/#{name}"

  def fetch(name) = described_class.call(url(name))

  # A response as Net::HTTP returns it, with its body already read.
  def response(klass, code, body: "", location: nil)
    klass.new("1.1", code, "").tap do
      it["location"] = location if location
      it.instance_variable_set(:@read, true)
      it.instance_variable_set(:@body, body)
    end
  end

  # Net::HTTP answers each URL with the response given for it and records the
  # URLs it was asked for.
  def serve(responses)
    allow(Net::HTTP).to receive(:get_response) do |uri|
      requested << uri.to_s
      responses.fetch(uri.to_s)
    end
  end

  # a → b → c → d → e, every one of them a redirect.
  def redirect_chain = %w[a b c d].zip(%w[b c d e]).to_h { [ url(it[0]), response(Net::HTTPFound, "302", location: url(it[1])) ] }

  it "200 時回傳狀態碼與內容" do
    serve(url("a") => response(Net::HTTPOK, "200", body: "內容"))
    expect(fetch("a")).to eq([ 200, "內容" ])
  end

  it "跟著轉址，回傳最後那個網址的狀態碼與內容" do
    serve(url("a") => response(Net::HTTPFound, "302", location: url("b")), url("b") => response(Net::HTTPOK, "200", body: "內容"))
    expect([ fetch("a"), requested ]).to eq([ [ 200, "內容" ], [ url("a"), url("b") ] ])
  end

  it "最多跟三次轉址：第四個回應仍是轉址時就回傳它的狀態碼，不再請求" do
    serve(redirect_chain)
    expect([ fetch("a"), requested ]).to eq([ [ 302, "" ], [ url("a"), url("b"), url("c"), url("d") ] ])
  end
end
