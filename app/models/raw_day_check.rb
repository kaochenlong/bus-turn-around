# Whether the raw files of one Taipei day are there for the day to be
# computed, as derived:load and the end nature survey both require: the day's
# bus_event hour files, the next day's 01 hour file that ends the read window,
# the day's bus_data hour files and the static snapshot files the stages
# read, checked in that order.
module RawDayCheck
  STATIC_FILES = %w[GetRoute.gz GetStop.gz GetPathDetail.gz].freeze

  # The day cannot be computed yet; the message names what is missing.
  class Failure < StandardError; end

  # The day's read window runs to 02:00 of the next day, so the day is only
  # computed once the next day's 01 hour file exists; before that a trip
  # across midnight would be cut short.
  def self.check!(data_root:, day:)
    bus_event = File.join(data_root, "bus_event")
    raise Failure, "#{bus_event}/#{day.iso8601} 沒有任何小時檔" if hour_files(bus_event, day.iso8601, "[0-9][0-9]").empty?

    next_day = (day + 1).iso8601
    if hour_files(bus_event, next_day, "01").empty?
      raise Failure, "讀檔視窗還沒結束：沒有 #{bus_event}/#{next_day}/01.jsonl 或 01.jsonl.gz"
    end

    # Only analysis/turnaround_facilities.sql reads the vehicle positions, and
    # DuckDB fails on an empty file list without naming the feed.
    bus_data = File.join(data_root, "bus_data")
    raise Failure, "#{bus_data}/#{day.iso8601} 沒有任何小時檔" if hour_files(bus_data, day.iso8601, "[0-9][0-9]").empty?

    static_dir = File.join(data_root, "static", day.iso8601)
    missing = STATIC_FILES.reject { File.file?(File.join(static_dir, it)) }
    raise Failure, "#{static_dir} 缺 #{missing.join('、')}" if missing.any?
  end

  def self.hour_files(root, day, hour) = Dir.glob("#{hour}.jsonl{,.gz}", base: File.join(root, day))
  private_class_method :hour_files
end
