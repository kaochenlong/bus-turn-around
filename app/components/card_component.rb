# frozen_string_literal: true

# A white card around blocks of the route page. The frame lives here rather
# than in the block components, so one card can hold several blocks.
class CardComponent < ApplicationComponent
  def initialize(id: nil)
    @id = id
  end
end
