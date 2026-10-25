class ApplicationController < ActionController::Base
  include Pagy::Method

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private

  # The page the server sends for an unknown address, rendered rather than
  # raised so that development and tests get it too. The file is a whole page:
  # render file: would otherwise wrap it in the layout.
  def render_not_found = render(file: Rails.public_path.join("404.html"), status: :not_found, layout: false)
end
