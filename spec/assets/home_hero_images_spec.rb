require "spec_helper"

# The hero images are exported from tools/hero and committed as files, so
# nothing else notices when one is missing or has grown past its budget.
RSpec.describe "app/assets/images/home-hero-*.webp" do
  def image_size(name) = File.size?(File.expand_path("../../app/assets/images/#{name}", __dir__))

  { "home-hero-wide.webp" => 200_000, "home-hero-narrow.webp" => 120_000 }.each do |name, budget|
    it "#{name} 存在，不超過 #{budget / 1000} KB" do
      expect(image_size(name)).to be_a(Integer).and be <= budget
    end
  end
end
