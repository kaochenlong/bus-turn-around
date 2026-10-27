// The day dispatch page in the browser, as in the requirements "Day dispatch
// page" and "Today's plan on the day dispatch page": it shows the day handed
// over in this tab that could not be kept, or else the day this browser
// keeps for the route for today; with neither, today's plan, laid out from
// the page's data as the timetable page lays out its sheets before any edit,
// offering the day kept for yesterday, and starts the day from it. The
// plan's timetable leads to the timetable page as the shown day was planned;
// starting again discards the day and shows today's plan again.
import { Turbo } from "@hotwired/turbo-rails"

import { previousDate, startDay, taipeiDate } from "./day.js"
import { handOver, release, takeOver } from "./day_handoff.js"
import { discardDay, loadDay, saveDay } from "./day_storage.js"
import { dayView } from "./day_view.js"
import { wholeInRange } from "./fields.js"
import { fill, formatDay } from "./format.js"
import { holdsFor, layOut } from "./layout.js"

export function dayDispatch() {
  return {
    init() {
      this.dayRoot = this.$root.querySelector("[data-day-dispatch]")
      this.startRoot = this.$root.querySelector("[data-day-start]")
      this.$root.querySelector("[data-needs-script]")?.setAttribute("hidden", "")
      this.routeId = Number(this.dayRoot.dataset.routeId)
      this.planTimetable = this.dayRoot.querySelector("[data-plan-timetable]")
      // The route's timetable page, as the server wrote the link.
      this.timetablePath = this.planTimetable.getAttribute("href")
      this.view = dayView(this.dayRoot, { now: () => this.now(), keep: (day) => this.keep(day) })
      this.dayRoot.querySelector("[data-restart]").addEventListener("click", () => this.restart())
      // The browser announces a print before it prints, from the record's
      // button or its own menu: the record is drawn then from the day shown.
      this.drawRecordBeforePrint = () => {
        if (!this.dayRoot.hidden) this.view.drawRecord()
      }
      window.addEventListener("beforeprint", this.drawRecordBeforePrint)
      this.initPlan()
      const handed = takeOver(this.routeId)
      const day = handed ?? this.kept(taipeiDate(this.now()))?.day
      if (day) {
        this.show(day, !handed)
        return
      }
      this.showPlan()
    },

    destroy() {
      window.removeEventListener("beforeprint", this.drawRecordBeforePrint)
    },

    // The page's clock, which the day dispatch reads for the Taipei date and
    // for now; the system specs replace it.
    now() {
      return new Date()
    },

    // This browser's local storage, or null when the browser denies access to
    // it.
    storage() {
      try {
        return window.localStorage
      } catch {
        return null
      }
    },

    // What this browser keeps for the route on a date: { day } or
    // { unreadable: true }, null without anything.
    kept(date) {
      return loadDay(this.storage(), this.routeId, date)
    },

    // Today's plan: the data the page embeds, nil without stored days of the
    // day type, and its controls. Changing the day type opens the page again
    // for it; changing the percentile or the rest only lays the plan out
    // again, and so does Enter in a field instead of sending the form.
    initPlan() {
      const script = this.$root.querySelector("script[data-plan-data]")
      this.data = script ? JSON.parse(script.textContent) : null
      this.startLabels = JSON.parse(this.startRoot.dataset.labels)
      this.planControls = this.startRoot.querySelector("[data-plan-controls]")
      this.planControls.addEventListener("change", (event) => (event.target.name === "type" ? this.openPlanOfType() : this.layPlan()))
      this.planControls.addEventListener("submit", (event) => {
        event.preventDefault()
        this.layPlan()
      })
      this.startRoot.querySelector("[data-start-button]")?.addEventListener("click", () => this.startTheDay())
      this.startRoot.querySelector("[data-continue]").addEventListener("click", () => this.show(this.yesterday, true))
    },

    // Today's plan in place of a day: today's date, the day kept for
    // yesterday to continue, a line when a day kept for today or yesterday
    // cannot be read, and the plan laid out.
    showPlan() {
      this.dayRoot.hidden = true
      this.startRoot.hidden = false
      const today = taipeiDate(this.now())
      const yesterday = previousDate(today)
      const found = { [today]: this.kept(today), [yesterday]: this.kept(yesterday) }
      this.startRoot.querySelector("[data-slot=date]").textContent = formatDay(this.startLabels, today)
      this.yesterday = found[yesterday]?.day ?? null
      const offer = this.startRoot.querySelector("[data-yesterday]")
      offer.hidden = !this.yesterday
      if (this.yesterday) offer.querySelector("[data-slot=yesterday]").textContent = fill(this.startLabels.yesterday, { date: formatDay(this.startLabels, yesterday) })
      const unreadable = [today, yesterday].find((date) => found[date]?.unreadable)
      const line = this.startRoot.querySelector("[data-unreadable]")
      line.hidden = !unreadable
      if (unreadable) line.textContent = fill(this.startLabels.unreadable, { date: formatDay(this.startLabels, unreadable) })
      this.layPlan()
    },

    // Today's plan laid out from the percentile and the rest in the controls,
    // a rest the timetable page would refuse written back as it was, and how
    // many vehicles and departures from each end it makes.
    layPlan() {
      if (!this.data) return
      this.percentile = Number(this.planControls.querySelector("select[name=p]").value)
      this.buffer = wholeInRange(this.planControls.querySelector("input[name=buffer]"), this.data.bufferRange, this.buffer ?? this.data.buffer)
      this.vehicles = layOut({ departures: this.data.departures, runTimes: this.data.runTimes, percentile: this.percentile, holds: holdsFor(this.data, this.buffer) })
      const trips = this.vehicles.flatMap((vehicle) => vehicle.trips)
      const counts = { vehicles: this.vehicles.length, "departures-0": trips.filter((trip) => trip.goBack === 0).length, "departures-1": trips.filter((trip) => trip.goBack === 1).length }
      for (const [slot, count] of Object.entries(counts)) this.startRoot.querySelector(`[data-slot="${slot}"]`).textContent = count
    },

    // The page again with today's plan for the selected day type, keeping the
    // percentile and the rest.
    openPlanOfType() {
      Turbo.visit(`${this.planControls.action}?${new URLSearchParams(new FormData(this.planControls))}`)
    },

    // The day started from today's plan as it stands, on the Taipei date of
    // now, kept in this browser or else handed over in this tab, and shown.
    startTheDay() {
      const now = this.now()
      const day = startDay(this.vehicles, {
        routeId: this.routeId,
        date: taipeiDate(now),
        startedAt: now.toISOString(),
        basis: { days: JSON.parse(this.startRoot.dataset.days), dayType: this.startRoot.dataset.dayType, percentile: this.percentile, buffer: this.buffer },
        stoppingEnds: this.data.stoppingEnds,
        runTimes: this.data.runTimes,
      })
      this.show(day, this.keep(day))
    },

    // Whether a changed day is kept in this browser; a day that cannot be is
    // handed over in this tab instead, so it is still there after leaving the
    // page and coming back.
    keep(day) {
      if (saveDay(this.storage(), day)) {
        release(this.routeId)
        return true
      }
      handOver(day)
      return false
    },

    show(day, kept) {
      this.startRoot.hidden = true
      this.dayRoot.hidden = false
      this.view.show(day, { kept })
      this.planTimetable.setAttribute("href", planningPath(this.timetablePath, day.basis))
    },

    // Once the dispatcher confirms, the day is discarded, here and in this
    // tab, and the same page shows today's plan.
    restart() {
      if (!window.confirm(this.view.labels.restartConfirm)) return
      discardDay(this.storage(), this.routeId, this.view.day.date)
      release(this.routeId)
      this.showPlan()
    },
  }
}

// The timetable page as a day was planned: its last covered day, one day or
// the seven-day range, the percentile and the rest minutes.
function planningPath(timetablePath, { days, percentile, buffer }) {
  const query = new URLSearchParams({ day: days.at(-1), range: days.length > 1 ? "7d" : "day", p: percentile, buffer })
  return `${timetablePath}?${query}`
}
