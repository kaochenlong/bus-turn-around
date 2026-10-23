# frozen_string_literal: true

# Links to the blocks of a route page in page order, kept at the top of the
# screen while scrolling. They are plain anchors and need no script. The nav
# carries no data-section, so the block order of the page stays the same.
class SectionNavComponent < ApplicationComponent
  # The id of the element that holds each block, in page order; it is also
  # the link's translation key.
  SECTIONS = %w[layovers buffer runtimes load mrt limits].freeze
end
