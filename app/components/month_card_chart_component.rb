# frozen_string_literal: true

# What the charts of a month card share. They are inline SVG drawn for paper: every
# chart sits next to a table or prints its own numbers, so nothing depends on hover.
# The two series colours passed the palette check on 2026-11-02 (design of
# 03-monthly-card); text stays grey, a mark beside it carries the identity.
class MonthCardChartComponent < ApplicationComponent
  SERIES_FIRST = "#0d9488"
  SERIES_SECOND = "#c2570c"
  FAINT = "#cbd5e1"
  GRID = "#e2e8f0"
  BOUNDARY = "#64748b"
end
