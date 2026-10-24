# frozen_string_literal: true

# The site name at the top of every page, as a link to the home page, and a
# link to the article that introduces the site, rendered by the layout before
# the page. It carries no data-section, so the block order of every page stays
# the same.
class SiteBarComponent < ApplicationComponent
  # The author's article on why and how the site was made. Like the site's
  # other links that leave it, it opens in the same tab.
  ABOUT_URL = "https://kaochenlong.com/bus-turn-around"
end
