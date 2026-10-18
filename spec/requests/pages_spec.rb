require "rails_helper"

RSpec.describe "Pages", type: :request do
  it "GET / 回應 200" do
    get root_path
    expect(response).to have_http_status(:ok)
  end
end
