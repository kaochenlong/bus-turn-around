require "yaml"

# The Taipei days bin/nightly-load loads, as config/derived_days.yml gives
# them: the first day, and the days that are not loaded, each with its
# reason. The file has no per-environment sections, because config_for merges
# a test section into the shared one and a test could not clear a skipped day
# of the shared section. A missing or extra key, a date not written
# YYYY-MM-DD, a day that does not exist or a skipped day without a reason is
# a configuration error whose message names the fault.
class DerivedDays
  KEYS = %w[first_day skipped_days].freeze
  ISO_DATE = /\A\d{4}-\d{2}-\d{2}\z/

  # The file does not hold together; the message says where.
  class InvalidConfiguration < StandardError; end

  # The days up to a moment: every day from the first day to the last
  # candidate day but the skipped ones, and the skipped days of that range
  # with their reasons.
  Candidates = Data.define(:first_day, :last_day, :days, :skipped_days)

  def self.from_config(path = Rails.root.join("config/derived_days.yml"))
    config = YAML.safe_load_file(path, permitted_classes: [ Date ])
    raise InvalidConfiguration, "#{path} 要是 first_day 與 skipped_days 兩個鍵的對應表" unless config.is_a?(Hash)

    missing, extra = KEYS - config.keys, config.keys - KEYS
    raise InvalidConfiguration, "#{path} 缺 #{missing.join('、')}" if missing.any?
    raise InvalidConfiguration, "#{path} 多出不認得的鍵：#{extra.join('、')}" if extra.any?

    skipped = config.fetch("skipped_days")
    raise InvalidConfiguration, "#{path} 的 skipped_days 要是日期對理由的對應表，沒有要跳過的日子就寫 {}" unless skipped.is_a?(Hash)

    new(first_day: date(config.fetch("first_day"), "first_day", path),
        skipped_days: skipped.to_h { |day, reason| [ date(day, "skipped_days 的日子", path), reason(reason, day, path) ] })
  rescue Psych::Exception, Errno::ENOENT => e
    raise InvalidConfiguration, "#{path} 讀不出來：#{e.message}"
  end

  # YAML reads an unquoted YYYY-MM-DD as a date; a quoted one, or a value
  # YAML could not read as a date, arrives as a string.
  def self.date(value, name, path)
    return value if value.is_a?(Date)
    raise InvalidConfiguration, "#{path} 的 #{name} 要寫成 YYYY-MM-DD：#{value}" unless value.is_a?(String) && ISO_DATE.match?(value)

    Date.iso8601(value)
  rescue Date::Error
    raise InvalidConfiguration, "#{path} 的 #{name} 沒有這一天：#{value}"
  end

  def self.reason(value, day, path)
    raise InvalidConfiguration, "#{path} 的 skipped_days 裡 #{day} 沒有寫理由" unless value.is_a?(String) && value.present?

    value
  end
  private_class_method :date, :reason

  attr_reader :first_day, :skipped_days

  # first_day is a Date and skipped_days maps each skipped Date to its reason.
  def initialize(first_day:, skipped_days:)
    @first_day = first_day
    @skipped_days = skipped_days
  end

  # The last day whose read window is over at `now`. A day's read window runs
  # to 02:00 of the next day (RawDayCheck), so the day two hours before `now`,
  # in Taipei time, is still being read and the day before it is the last.
  def last_candidate_day(now) = (now.in_time_zone("Taipei") - 2.hours).to_date - 1

  def candidates(now:)
    last_day = last_candidate_day(now)
    range = first_day..last_day
    skipped = skipped_days.select { |day, _| range.cover?(day) }
    Candidates.new(first_day:, last_day:, days: range.reject { skipped.key?(it) }, skipped_days: skipped)
  end
end
