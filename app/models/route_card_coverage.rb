# Which days of a month a route's card covers, as in the monthly-card spec. Every
# day of the month is loaded when its route day is stored; missing when it is
# before the first day collected, when it is skipped, or when its read window is
# over and its raw files fail the check; and waiting otherwise. A day whose raw
# files are gone will never come back, so it must not hold the card up, while a
# day that is merely not loaded yet must not be printed as missing. It needs the
# machine with the raw files and the office calendar.
class RouteCardCoverage
  NOT_STARTED = "還沒開始收資料".freeze
  RAW_FILES_INCOMPLETE = "原始檔不齊".freeze
  WEEKDAY = "weekday".freeze
  HOLIDAY = "holiday".freeze

  # `days` is a DerivedDays; `check` answers like RawDayCheck.
  def initialize(route_id:, month:, data_root:, days:, now:, check: RawDayCheck)
    @route_id = route_id
    @month = month
    @data_root = data_root
    @days = days
    @now = now
    @check = check
  end

  def ready? = waiting_days.empty?

  def partial? = RouteCard.partial?(to_h)

  # The days of the month that are neither loaded nor known to be missing.
  def waiting_days = statuses.select { |_, status| status == :waiting }.keys

  # What route_cards stores: string keys and ISO dates, so that it reads back
  # from jsonb the same as it was written.
  def to_h
    @to_h ||= { "calendar_weekdays" => calendar_days(WEEKDAY).size, "calendar_holidays" => calendar_days(HOLIDAY).size,
                "loaded_weekdays" => (loaded_days & calendar_days(WEEKDAY)).size, "loaded_holidays" => (loaded_days & calendar_days(HOLIDAY)).size,
                "missing" => missing_stretches }
  end

  private

  def month_days = @month..@month.end_of_month

  # Day => :loaded, :waiting or the reason it is missing, in day order.
  def statuses = @statuses ||= month_days.to_h { [ it, status(it) ] }

  def status(day)
    return :loaded if stored_days.include?(day)
    return NOT_STARTED if day < @days.first_day
    return @days.skipped_days.fetch(day) if @days.skipped_days.key?(day)
    return :waiting if day > @days.last_candidate_day(@now)

    raw_files_complete?(day) ? :waiting : RAW_FILES_INCOMPLETE
  end

  def raw_files_complete?(day)
    @check.check!(data_root: @data_root, day:)
    true
  rescue RawDayCheck::Failure
    false
  end

  def stored_days = @stored_days ||= RouteDay.where(route_id: @route_id, day: month_days).pluck(:day).to_set

  def loaded_days = statuses.select { |_, status| status == :loaded }.keys

  def calendar_days(day_type) = day_types.select { |_, type| type == day_type }.keys

  # What the office calendar calls each day of the month, not what the route days
  # stored say: most of the month may not be stored.
  def day_types
    @day_types ||= month_days.to_h { [ it, OfficeCalendarSnapshot.entry(data_root: @data_root, day: it).day_type ] }
  end

  # Adjacent days missing for the same reason, as one entry each. A stretch
  # across weekdays and holidays has no day type.
  def missing_stretches
    statuses.reject { |_, status| %i[loaded waiting].include?(status) }.to_a
            .slice_when { |(earlier, reason), (later, next_reason)| later != earlier + 1 || reason != next_reason }
            .map do |stretch|
      types = stretch.map { |day, _| day_types.fetch(day) }.uniq
      { "from" => stretch.first.first.iso8601, "to" => stretch.last.first.iso8601, "day_type" => types.one? ? types.first : nil, "reason" => stretch.first.last }
    end
  end
end
