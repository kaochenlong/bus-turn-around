module RoutePage
  # The sentences of 這個月看到的事 on the first page of a month card, built by rules
  # from the weekdays' figures, as in the monthly-card spec. A sentence whose
  # condition does not hold is left out, and none of them says why anything is so.
  # The thresholds only describe; they are in no definition.
  class MonthFindings
    # An hour needs this many layovers to be named.
    MIN_HOUR_LAYOVERS = 10
    # The share under 15 minutes from which an hour is named as concentrated.
    CONCENTRATED_SHARE = 0.6
    # A starting hour needs this many round trips and cycles to be named.
    MIN_HOUR_VALUES = 5
    # Cycle p10 and round trip p50 closer than this leave a vehicle no spare time.
    TIGHT_MINUTES = 4
    # The other periods the fourth sentence compares start in these minutes of the
    # day, which leaves out the thin early and late periods.
    OTHER_PERIOD_STARTS = (8 * 60)...(20 * 60)

    # Whether a starting hour's cycles leave a vehicle no spare time: enough values
    # of both, and cycle p10 close to round trip p50.
    def self.tight?(row)
      return false if row.n_round_trips < MIN_HOUR_VALUES || row.n_cycles < MIN_HOUR_VALUES

      (row.cycle_percentiles.first - row.round_trip_percentiles.first).abs < TIGHT_MINUTES
    end

    def initialize(month_card)
      @card = month_card
    end

    def sentences = [ *layover_sentences, tight_hours_sentence, windows_sentence, schedule_sentence ].compact

    private

    # One per stopping end; the end is named only when there are two.
    def layover_sentences
      rows = @card.layover_stats(:weekday).rows.select { @card.stop_go_backs.include?(it.go_back) && it.short_share }
      rows.map do |row|
        subject = @card.stop_go_backs.size > 1 ? row.stop_name : "停車端"
        hours = @card.layover_hours.rows(row.go_back).select { it.n_layovers >= MIN_HOUR_LAYOVERS }
        concentrated = hours.select { it.short_share >= CONCENTRATED_SHARE }
        "#{subject}的折返停留有 #{percent(row.short_share)} 不到 15 分鐘#{concentrated_clause(concentrated)}#{lowest_clause(hours, concentrated)}。"
      end
    end

    def concentrated_clause(hours)
      return "" if hours.empty?

      "，集中在 #{joined(consecutive(hours, &:hour).map { hour_span(it) })}回來的車"
    end

    # Left out when the lowest hour is itself a concentrated one, or the sentence
    # would say both that the layovers gather there and that only so many do.
    def lowest_clause(hours, concentrated)
      lowest = hours.min_by { [ it.short_share, it.hour ] }
      return "" if lowest.nil? || concentrated.include?(lowest)

      "；#{two_digits(lowest.hour)} 時回來的車只有 #{percent(lowest.short_share)}"
    end

    def hour_span(hours)
      shares = hours.map { percent(it.short_share) }.uniq
      low, high = hours.map(&:short_share).minmax
      share_text = shares.one? ? shares.first : "#{percent(low)} 到 #{percent(high)}"
      "#{hours_label(hours.map(&:hour))} 時（#{share_text}）"
    end

    def tight_hours_sentence
      hours = @card.cycles(:weekday).rows.select { self.class.tight?(it) }.map(&:hour)
      return if hours.empty?

      labels = consecutive(hours) { it }.map { hours_label(it) }
      "#{labels.join('、')} 時發車的車，週期最緊的一成跟來回一趟的中位數差不到 #{TIGHT_MINUTES} 分鐘，車回到停車端幾乎沒有多餘的時間。"
    end

    def windows_sentence
      rule = @card.rest_windows(:weekday).rule(:four_hours)
      return if rule.n_windows.zero?

      "能判斷的連續 4 小時裡，有 #{percent(rule.flagged_share)} 停留累計不到 30 分鐘。這是車的數字：其中 #{percent(rule.n_over_daily.fdiv(rule.n_windows))} 的視窗" \
        "落在當天行駛超過 10 小時的車上，這種車若守每日駕車 10 小時的規定就換過人。"
    end

    def schedule_sentence
      version = @card.schedule(:weekday).versions.last
      return unless version

      version.periods.any? ? periods_sentence(version) : departures_sentence(version)
    end

    def periods_sentence(version)
      peaks = @card.peak_periods(:weekday)
      others = (version.periods - peaks).select { OTHER_PERIOD_STARTS.cover?(it.start_minute) }
      headway = span(peaks.map(&:low_minutes).min, peaks.map(&:high_minutes).max, "–")
      "尖峰公告 #{headway} 分一班，#{needed_clause(peaks, '照現在的週期要 %s 台車，')}量到路上約 #{on_road_span(peaks)} 台。#{others_clause(others)}差距的原因公開資料看不出來。"
    end

    def others_clause(others)
      return "" if others.empty?

      "其他時段#{needed_clause(others, '用同一個算法是 %s 台，')}路上約 #{on_road_span(others)} 台。"
    end

    # Nothing without a cycle: nothing can be said about the vehicles needed.
    def needed_clause(periods, wording)
      low, high = periods.filter_map(&:needed_low).min, periods.filter_map(&:needed_high).max
      low && high ? format(wording, span(low, high, "–")) : ""
    end

    def on_road_span(periods)
      low, high = periods.map { it.on_road.round }.minmax
      span(low, high, " 到 ")
    end

    def departures_sentence(version)
      others = version.others
      return unless others&.departures&.any?

      out, back = others.trips_per_day.values_at(0, 1).map(&:round)
      trips = out == back ? "每個方向約 #{out} 趟" : "去程約 #{out} 趟、返程約 #{back} 趟"
      "定時班次一天 #{others.departures.size} 班，量到#{trips}。"
    end

    # Runs of consecutive hours, in order, by the hour the block reads from an item.
    def consecutive(items, &hour) = items.slice_when { |earlier, later| hour.call(later) != hour.call(earlier) + 1 }.to_a

    def hours_label(hours) = hours.one? ? two_digits(hours.first) : "#{two_digits(hours.first)} 到 #{two_digits(hours.last)}"

    def two_digits(hour) = format("%02d", hour)

    # 08 時、09 時與 11 時: the parts start with a digit, so a space goes before it.
    def joined(parts) = parts.one? ? parts.first : "#{parts[0..-2].join('、')}與 #{parts.last}"

    def span(low, high, separator) = low == high ? low.to_s : "#{low}#{separator}#{high}"

    def percent(share) = "#{(share * 100).round}%"
  end
end
