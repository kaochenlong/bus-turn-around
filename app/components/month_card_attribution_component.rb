# frozen_string_literal: true

# The attribution a printed month card carries, as in the monthly-card spec: only
# the sources this card uses, because naming the others would not be true. The
# licence requires it, and the print leaves out the site's own footer.
class MonthCardAttributionComponent < ApplicationComponent
  def repository = SiteBarComponent::REPOSITORY_URL.delete_prefix("https://")

  def version = ProgramVersion.current
end
