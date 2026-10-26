// The day dispatch view of the timetable page, as in the day-dispatch spec:
// draws a day, worked out by day.js, into the markup and the templates that
// DayDispatchComponent writes, with the words of its data-labels; times read
// like the sheets', with the words for times the sheets share.
// Vehicles are named by the sheets' numbers only. Every change the
// dispatcher makes goes through day.js, is kept in this browser and draws the
// whole view anew; a change that cannot be made is explained beside the
// field it came from and changes nothing.
import { arrivingAt, changeDeparture, changeVehicle, currentDay, defaultEnd, departuresAt, minutesOfDay, recordArrival, undoLast, vehiclesAt } from "./day.js"
import { clock, fieldClock, parseClock, stopText } from "./format.js"

// The words for each refusal of a vehicle change.
const REFUSALS = { elsewhere: "elsewhere", "day-ended": "dayEnded", "no-trips": "noTrips" }

// The view inside the component's root. now is the page's clock, read
// whenever it is needed; keep(day) keeps a changed day and says whether this
// browser holds it.
export function dayView(root, { now, keep }) {
  const labels = JSON.parse(root.dataset.labels)
  const template = (name) => root.querySelector(`template[data-${name}]`)
  const slot = (name) => root.querySelector(`[data-slot=${name}]`)
  const time = (minutes) => clock(minutes, labels.nextDay)
  const vehicleName = (number) => fill(labels.vehicle, { number })
  const endName = (end) => root.querySelector(`[data-end="${end}"]`).dataset.name
  const changeReason = root.querySelector("[data-change-reason]")
  const form = root.querySelector("form[data-record]")

  // What is said about a typed time that cannot be read, in the sheets'
  // words: it quotes what was typed, when anything was, as text.
  const rejectedText = (typed) => (typed.trim() === "" ? labels.acceptedWritings : labels.rejectedTyped.replace("%{typed}", () => typed.trim()))

  const view = {
    labels,
    day: null,
    // The end whose departures are listed.
    end: null,
    // The departure field typed into since it was last submitted, if any.
    typedField: null,
    // The field whose change was refused and the row that says why, if any.
    rejection: null,

    // A day shown from the end listed first, saying when it is not kept in
    // this browser.
    show(day, { kept }) {
      this.day = day
      this.end = defaultEnd(day)
      root.querySelector("[data-not-kept]").hidden = kept
      this.render()
    },

    selectEnd(end) {
      this.end = end
      this.render()
    },

    // A change made: the day kept, drawn anew, and the focus back on the
    // control of the trip the dispatcher was on, when there is one.
    commit(day, focus = null) {
      this.day = day
      root.querySelector("[data-not-kept]").hidden = keep(day)
      this.render()
      if (focus) root.querySelector(`tr[data-trip="${focus.trip}"] [data-control=${focus.control}]`)?.focus()
    },

    // A change from the departures' cells, which takes the reason typed
    // above them and empties it.
    commitFromTable(day, focus) {
      changeReason.value = ""
      this.commit(day, focus)
    },

    // A departure typed anew, when its field is left or on Enter: a time that
    // cannot be read is rejected and the previous time put back; the trip's
    // own time again only rewrites the field. As on the sheets, a field not
    // typed into since it was last submitted has nothing to submit.
    submitDeparture(field, next) {
      if (field !== this.typedField) return
      this.typedField = null
      const tr = field.closest("tr[data-trip]")
      const current = Number(tr.dataset.departure)
      const minutes = parseClock(field.value)
      if (minutes === null) {
        this.reject(tr, field, rejectedText(field.value), true)
        field.value = fieldClock(current)
        return
      }
      this.clearRejection()
      if (minutes === current) {
        field.value = fieldClock(minutes)
        return
      }
      const day = changeDeparture(this.day, { tripId: tr.dataset.trip, departure: minutes, reason: changeReason.value.trim(), at: now().toISOString() })
      this.commitFromTable(day, focusOf(next))
    },

    // A departure given to the vehicle picked in its menu; when the change
    // is refused the menu goes back to the departure's vehicle.
    giveDeparture(menu) {
      const tr = menu.closest("tr[data-trip]")
      const result = changeVehicle(this.day, { tripId: tr.dataset.trip, vehicle: Number(menu.value), reason: changeReason.value.trim(), at: now().toISOString() })
      if (result.refused) {
        const { kind, vehicle, end } = result.refused
        menu.value = tr.dataset.vehicle
        // A vehicle with no trip left has no end to name.
        this.reject(tr, menu, fill(labels[REFUSALS[kind]], { vehicle: vehicleName(vehicle), stop: end === undefined ? "" : endName(end) }), false)
        return
      }
      this.commitFromTable(result, { trip: tr.dataset.trip, control: "vehicle" })
    },

    // A vehicle recorded back at the selected end from the form; the time
    // and the reason are emptied once it is recorded.
    record(event) {
      event.preventDefault()
      const timeField = form.querySelector("[data-record-time]")
      const minutes = parseClock(timeField.value)
      if (minutes === null) {
        this.formMessage(timeField, rejectedText(timeField.value))
        return
      }
      const vehicle = Number(form.querySelector("[data-record-vehicle]").value)
      const reasonField = form.querySelector("[data-record-reason]")
      const result = recordArrival(this.day, { vehicle, end: this.end, time: minutes, reason: reasonField.value.trim(), at: now().toISOString() })
      if (result.refused) {
        this.formMessage(null, fill(labels.noTrip, { vehicle: vehicleName(vehicle), time: time(minutes), stop: endName(this.end) }))
        return
      }
      timeField.value = ""
      reasonField.value = ""
      this.formMessage(null, null)
      this.commit(result)
    },

    // The form's message, or none; the field it is about, if any, is marked
    // invalid and pointed at it.
    formMessage(field, text) {
      const message = form.querySelector("[data-record-message]")
      const timeField = form.querySelector("[data-record-time]")
      timeField.removeAttribute("aria-invalid")
      timeField.removeAttribute("aria-describedby")
      message.hidden = text === null
      message.textContent = text ?? ""
      if (!field) return
      field.setAttribute("aria-invalid", "true")
      field.setAttribute("aria-describedby", message.id)
    },

    // Why a change from a cell was not made, in a row under the departure's;
    // the field points at it and, for a time that cannot be read, is marked
    // invalid. Only the latest one is shown.
    reject(tr, field, text, invalid) {
      this.clearRejection()
      const row = template("row-message").content.firstElementChild.cloneNode(true)
      const message = row.querySelector("p")
      message.id = `day-message-${tr.dataset.trip}`
      message.textContent = text
      tr.after(row)
      if (invalid) field.setAttribute("aria-invalid", "true")
      field.setAttribute("aria-describedby", message.id)
      this.rejection = { field, row }
    },

    clearRejection() {
      if (!this.rejection) return
      const { field, row } = this.rejection
      field.removeAttribute("aria-invalid")
      field.removeAttribute("aria-describedby")
      row.remove()
      this.rejection = null
    },

    render() {
      this.rejection = null
      const current = currentDay(this.day)
      const minutes = minutesOfDay(this.day.date, now())
      slot("date").textContent = formatDay(labels, this.day.date)
      slot("basis").textContent = basisText(labels, this.day.basis)
      this.renderFigures(current.figures)
      for (const button of root.querySelectorAll("[data-end]")) button.setAttribute("aria-pressed", String(Number(button.dataset.end) === this.end))
      slot("arrival-column").textContent = fill(labels.arrivalColumn, { stop: endName(this.end) })
      slot("departures").replaceChildren(...this.departureRows(current, minutes))
      this.renderStanding(current, minutes)
      this.renderCredits(current.credits)
      this.renderRecordForm(current)
      this.renderChanges()
    },

    renderFigures({ swaps, typed, waiting, shortestStop }) {
      const figure = (name, value) => { root.querySelector(`[data-figure=${name}]`).textContent = value }
      figure("swaps", swaps)
      figure("typed", typed)
      figure("waiting", waiting)
      figure("shortest", shortestStop?.minutes ?? labels.none)
      slot("shortest-detail").textContent = shortestStop ? fill(labels.shortestDetail, { vehicle: vehicleName(shortestStop.vehicle), departure: time(shortestStop.departure) }) : ""
    },

    // The departures from the selected end, with the line of now before the
    // first one at or after now, or after the last.
    departureRows(current, minutes) {
      const vehicles = current.vehicles.map((vehicle) => vehicle.number)
      const departures = departuresAt(current, this.end, minutes)
      const rows = departures.map((row) => this.departureRow(row, vehicles))
      const later = departures.findIndex((row) => row.departure >= minutes)
      rows.splice(later === -1 ? rows.length : later, 0, this.nowLine(minutes))
      return rows
    },

    // One departure: its typed time in its field, its planned vehicle, its
    // vehicle in a menu of every vehicle with the planned one under it when
    // they differ, the arrival before it (marked when recorded), the stop and
    // the status.
    departureRow(row, vehicles) {
      const tr = template("departure-row").content.firstElementChild.cloneNode(true)
      const departure = time(row.departure)
      tr.dataset.trip = row.id
      tr.dataset.departure = row.departure
      tr.dataset.vehicle = row.vehicle
      tr.dataset.status = row.status
      tr.toggleAttribute("data-swapped", row.vehicle !== row.plannedVehicle)
      const field = tr.querySelector("[data-control=departure]")
      field.value = fieldClock(row.departure)
      field.setAttribute("aria-label", fill(labels.departureField, { time: departure }))
      tr.querySelector("[data-slot=planned]").textContent = vehicleName(row.plannedVehicle)
      const menu = tr.querySelector("[data-control=vehicle]")
      menu.setAttribute("aria-label", fill(labels.vehicleField, { time: departure }))
      menu.replaceChildren(...vehicles.map((number) => new Option(vehicleName(number), number, false, number === row.vehicle)))
      tr.querySelector("[data-slot=swapped]").textContent = row.vehicle === row.plannedVehicle ? "" : fill(labels.swapped, { vehicle: vehicleName(row.plannedVehicle) })
      tr.querySelector("[data-slot=arrival]").textContent = row.arrival === null ? "" : time(row.arrival)
      tr.querySelector("[data-slot=recorded]").hidden = !row.recorded
      tr.querySelector("[data-slot=stop]").textContent = stopText(row.stop)
      tr.querySelector("[data-slot=status]").textContent = labels.statuses[row.status]
      return tr
    },

    nowLine(minutes) {
      const tr = template("now-line").content.firstElementChild.cloneNode(true)
      tr.querySelector("[data-slot=now]").textContent = fill(labels.nowLine, { time: time(minutes) })
      return tr
    },

    // The vehicles standing at the selected end now and the ones due there
    // next, each with its next departure or the end of its day.
    renderStanding(current, minutes) {
      const stop = endName(this.end)
      slot("standing-heading").textContent = fill(labels.standingHeading, { stop, time: time(minutes) })
      const standing = vehiclesAt(current, this.end, minutes)
      slot("standing").replaceChildren(...standing.map((row) => this.item("standing-item", {
        vehicle: vehicleName(row.vehicle),
        detail: fill(row.next === null ? labels.standingEnded : labels.standingNext, { arrival: time(row.arrival), minutes: row.stood, next: row.next === null ? "" : time(row.next) }),
      })))
      root.querySelector("[data-standing-none]").hidden = standing.length > 0
      const arriving = arrivingAt(current, this.end, minutes)
      slot("arriving").replaceChildren(...arriving.map((row) => this.item("arriving-item", {
        vehicle: vehicleName(row.vehicle),
        arrival: time(row.arrival),
        next: row.next === null ? labels.arrivingEnded : fill(labels.arrivingNext, { next: time(row.next) }),
      })))
      root.querySelector("[data-arriving-none]").hidden = arriving.length > 0
    },

    // Every vehicle's rest in the tightest four hours now, with the planned
    // value beside it when the two differ.
    renderCredits(credits) {
      const minutesText = (minutes, shorter, text) => (minutes === null ? shorter : fill(text, { minutes }))
      slot("credits").replaceChildren(...credits.map((credit) => this.item("credit-item", {
        vehicle: vehicleName(credit.vehicle),
        now: minutesText(credit.now, labels.creditShorter, labels.creditMinutes),
        planned: credit.now === credit.planned ? "" : minutesText(credit.planned, labels.creditPlannedShorter, labels.creditPlanned),
      })))
    },

    // The record form for the selected end, offering every vehicle and
    // keeping the one chosen.
    renderRecordForm(current) {
      slot("record-heading").textContent = fill(labels.recordHeading, { stop: endName(this.end) })
      const menu = root.querySelector("[data-record-vehicle]")
      const chosen = menu.value
      menu.replaceChildren(...current.vehicles.map(({ number }) => new Option(vehicleName(number), number, false, String(number) === chosen)))
    },

    // Every change in the order recorded: when, in Taipei time, what it did
    // and its reason; an undone one stays, marked. Undo is offered while a
    // change is in effect.
    renderChanges() {
      const { changes } = this.day
      slot("changes-heading").textContent = fill(labels.changesHeading, { count: changes.length })
      slot("changes").replaceChildren(...changes.map((change) => {
        const li = this.item("change-item", {
          at: time(minutesOfDay(this.day.date, new Date(change.at))),
          text: this.changeText(change),
          reason: change.reason ? fill(labels.changeReason, { reason: change.reason }) : "",
        })
        li.toggleAttribute("data-undone", change.undone)
        li.querySelector("[data-slot=undone]").hidden = !change.undone
        return li
      }))
      root.querySelector("[data-changes-none]").hidden = changes.length > 0
      root.querySelector("[data-undo]").disabled = changes.every((change) => change.undone)
    },

    // What a change did, from what the log kept when it was made.
    changeText(change) {
      if (change.kind === "arrival") return fill(labels.changeArrival, { vehicle: vehicleName(change.vehicle), time: time(change.time), stop: endName(change.end) })
      if (change.kind === "vehicle") {
        const departsFrom = this.day.plan.flatMap((vehicle) => vehicle.trips).find((trip) => trip.id === change.tripId).goBack
        return fill(labels.changeVehicle, { departure: time(change.departure), stop: endName(departsFrom), vehicle: vehicleName(change.vehicle), from: vehicleName(change.from) })
      }
      return fill(labels.changeDeparture, { vehicle: vehicleName(change.vehicle), from: time(change.from), departure: time(change.departure) })
    },

    // A list item from its template, its slots filled with the texts.
    item(name, texts) {
      const li = template(name).content.firstElementChild.cloneNode(true)
      for (const [key, text] of Object.entries(texts)) li.querySelector(`[data-slot=${key}]`).textContent = text
      return li
    },
  }

  for (const button of root.querySelectorAll("[data-end]")) button.addEventListener("click", () => view.selectEnd(Number(button.dataset.end)))
  const departures = slot("departures")
  const departureField = (event) => event.target.closest("[data-control=departure]")
  departures.addEventListener("input", (event) => {
    if (departureField(event)) view.typedField = departureField(event)
  })
  departures.addEventListener("focusout", (event) => {
    if (departureField(event)) view.submitDeparture(departureField(event), event.relatedTarget)
  })
  departures.addEventListener("keydown", (event) => {
    if (event.key !== "Enter" || !departureField(event)) return
    event.preventDefault()
    view.submitDeparture(departureField(event), departureField(event))
  })
  departures.addEventListener("change", (event) => {
    const menu = event.target.closest("[data-control=vehicle]")
    if (menu) view.giveDeparture(menu)
  })
  form.addEventListener("submit", (event) => view.record(event))
  root.querySelector("[data-undo]").addEventListener("click", () => view.commit(undoLast(view.day)))
  return view
}

// The trip and the control a focused element is, when it is one of a
// departure's controls, so the focus can go back to it once the view is
// drawn anew.
function focusOf(element) {
  const tr = element?.closest?.("tr[data-trip]")
  return tr && element.dataset.control ? { trip: tr.dataset.trip, control: element.dataset.control } : null
}

// A YYYY-MM-DD date with its weekday, as the site writes days.
export function formatDay(labels, date) {
  return fill(labels.dayLabel, { date, weekday: labels.weekdays[new Date(Date.parse(date)).getUTCDay()] })
}

// A label with its %{name} placeholders filled. The values go in as text, so
// a typed reason is never read as a pattern; a placeholder without a value
// stays as it is.
export function fill(text, values) {
  return text.replace(/%\{(\w+)\}/g, (placeholder, name) => (Object.hasOwn(values, name) ? String(values[name]) : placeholder))
}

// What the day was planned from: the covered day or days with their day
// type, the percentile and the rest minutes.
function basisText(labels, { days, dayType, percentile, buffer }) {
  const values = { dayType: labels.dayTypes[dayType], percentile, buffer }
  if (days.length === 1) return fill(labels.basisOne, { ...values, day: formatDay(labels, days[0]) })
  return fill(labels.basisRange, { ...values, first: formatDay(labels, days[0]), last: formatDay(labels, days.at(-1)), count: days.length })
}
