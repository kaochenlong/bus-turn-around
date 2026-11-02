require "yaml"

# The months that get a printed month card, as config/route_cards.yml gives them:
# from the first month up to the last Taipei month that is over. The file has no
# per-environment sections, like config/derived_days.yml. A missing or extra key
# or a month not written YYYY-MM is a configuration error whose message names the
# fault.
class CardMonths
  KEYS = %w[first_month].freeze
  MONTH = /\A\d{4}-(0[1-9]|1[0-2])\z/

  # The file does not hold together; the message says where.
  class InvalidConfiguration < StandardError; end

  def self.from_config(path = Rails.root.join("config/route_cards.yml"))
    config = YAML.safe_load_file(path)
    raise InvalidConfiguration, "#{path} 要是 first_month 這個鍵的對應表" unless config.is_a?(Hash)

    missing, extra = KEYS - config.keys, config.keys - KEYS
    raise InvalidConfiguration, "#{path} 缺 #{missing.join('、')}" if missing.any?
    raise InvalidConfiguration, "#{path} 多出不認得的鍵：#{extra.join('、')}" if extra.any?

    value = config.fetch("first_month")
    new(first_month: parse(value) || raise(InvalidConfiguration, "#{path} 的 first_month 要寫成 YYYY-MM：#{value}"))
  rescue Psych::Exception, Errno::ENOENT => e
    raise InvalidConfiguration, "#{path} 讀不出來：#{e.message}"
  end

  # The first day of the month a YYYY-MM names, nil when it names none.
  def self.parse(text) = (Date.iso8601("#{text}-01") if MONTH.match?(text.to_s))

  attr_reader :first_month

  # first_month is the first day of the month.
  def initialize(first_month:)
    @first_month = first_month
  end

  # The months over at `now`, oldest first: the current one is still being collected.
  def due(now:) = (first_month..last_over(now)).select { it.day == 1 }

  # The month of the first printed card, for a route without one: a route that joins
  # later has no use for a month that has gone by.
  def first_to_print(now:) = [ first_month, last_over(now) ].max

  private

  def last_over(now) = now.in_time_zone("Taipei").to_date.prev_month.beginning_of_month
end
