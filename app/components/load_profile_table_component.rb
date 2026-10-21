# frozen_string_literal: true

# The load profile: one row per stop of a direction, one column per time band;
# each cell is the median and p90 of the on-board count with the number of
# trips that had a count there.
class LoadProfileTableComponent < ApplicationComponent
  BANDS = %w[morning_peak daytime evening_peak other].freeze
  NONE = "—"

  def initialize(load_profile:)
    @load_profile = load_profile
  end

  # [go_back, seq, stop_name] => { band => row }, in direction and stop order.
  def stops
    @stops ||= @load_profile.rows.group_by { [ it.go_back, it.seq, it.stop_name ] }
                            .sort_by { |(go_back, seq, _), _| [ go_back, seq ] }
                            .to_h { |key, rows| [ key, rows.index_by(&:band) ] }
  end

  def cell(row) = row ? format("%.1f / %.1f（%d）", row.median, row.p90, row.n_trips) : NONE
end
