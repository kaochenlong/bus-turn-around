# frozen_string_literal: true

# The load profile: one group of rows per direction, one row per stop, one
# column per time band; each cell is the median and p90 of the on-board count
# with the number of trips that had a count there.
class LoadProfileTableComponent < ApplicationComponent
  BANDS = %w[morning_peak daytime evening_peak other].freeze
  NONE = "—"

  def initialize(load_profile:)
    @load_profile = load_profile
  end

  # go_back => { [seq, stop_name] => { band => row } }, directions and stops in order.
  def directions
    @directions ||= @load_profile.rows.group_by(&:go_back).sort.to_h do |go_back, rows|
      stops = rows.group_by { [ it.seq, it.stop_name ] }.sort_by { |(seq, _), _| seq }
      [ go_back, stops.to_h { |stop, stop_rows| [ stop, stop_rows.index_by(&:band) ] } ]
    end
  end

  def decimal(value) = format("%.1f", value)
end
