// The day dispatch view of the day dispatch page, as in the day-dispatch
// spec: draws a day, worked out by day.js, into the markup and the templates
// that DayDispatchComponent writes, with the words of its data-labels, and
// its timeline through day_timeline_view.js; times read like the sheets',
// with the words for times the sheets share.
// Vehicles are named by the sheets' numbers only. Every change the
// dispatcher makes goes through day.js, is kept in this browser and draws the
// whole view anew; a change that cannot be made is explained beside the
// field it came from and changes nothing. As the clock moves on, only what
// depends on now is drawn anew. The day record's two files are made
// here from the day, by day_record.js, and downloaded without a request; the
// printed record is drawn from the day when the browser is about to print.
import { arrivingAt, changeDeparture, changeVehicle, currentDay, defaultEnd, departuresAt, minutesOfDay, recordArrival, undoLast, vehiclesAt } from "./day.js"
import { changeLogCsv, csvFileName, marksFor, sheetHeader, sheetNotes, sheetsCsv } from "./day_record.js"
import { timelineView } from "./day_timeline_view.js"
import { clock, fieldClock, fill, formatDay, minutesText, parseClock, stopText } from "./format.js"
import { OTHER_END } from "./layout.js"
import { sheetView } from "./sheet_view.js"

// The words for each refusal of a vehicle change.
const REFUSALS = { elsewhere: "elsewhere", "day-ended": "dayEnded", "no-trips": "noTrips" }

// How many departures show above the one the panel scrolls to, as on the
// canvas.
const PANEL_CONTEXT = 3

// How long a downloaded file's address is kept: a browser may still be
// reading the file when the click that started the download returns.
const DOWNLOAD_KEPT_MS = 60 * 1000

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
  const departuresFrame = root.querySelector("[data-departures-frame]")
  // The printed record's sheets, from the timetable's sheet templates.
  const sheets = sheetView(root.querySelector("template[data-sheet-template]"), root.querySelector("template[data-row-template]"))
  const timelineSection = root.querySelector("[data-day-timeline]")
  // The timeline's words, which name the selected trip.
  const timelineWords = JSON.parse(timelineSection.dataset.labels)
  const timeline = timelineView(timelineSection, {
    labels, time, vehicleName, endName,
    onSelect: (tripId, how) => view.select(tripId, how), onNow: () => view.toNow(),
    previewDrop: (tripId, vehicle) => view.previewDrop(tripId, vehicle), onDropOnLane: (tripId, vehicle) => view.dropOnLane(tripId, vehicle),
    onDropAlongLane: (tripId, departure) => view.dropAlongLane(tripId, departure),
  })

  // Why a vehicle change was refused, in the panel's words: the vehicle and
  // the end it next leaves from or ends its day at. A vehicle with no trip
  // left has no end to name.
  const refusalText = ({ kind, vehicle, end }) => fill(labels[REFUSALS[kind]], { vehicle: vehicleName(vehicle), stop: end === undefined ? "" : endName(end) })

  // What is said about a typed time that cannot be read, in the sheets'
  // words: it quotes what was typed, when anything was, as text.
  const rejectedText = (typed) => (typed.trim() === "" ? labels.acceptedWritings : labels.rejectedTyped.replace("%{typed}", () => typed.trim()))

  const view = {
    labels,
    day: null,
    // The end whose departures are listed.
    end: null,
    // The identifier of the trip selected on the timeline, if any.
    selected: null,
    // The departure field typed into since it was last submitted, if any.
    typedField: null,
    // The field whose change was refused and the row that says why, if any.
    rejection: null,

    // A day shown from the end listed first, its departures scrolled to the
    // next one and its timeline to now, saying when it is not kept in this
    // browser.
    show(day, { kept }) {
      this.day = day
      this.end = defaultEnd(day)
      this.selected = null
      root.querySelector("[data-not-kept]").hidden = kept
      this.render()
      this.scrollPanelToNow()
      timeline.scrollToNow()
    },

    selectEnd(end) {
      this.end = end
      this.render()
    },

    // A trip selected on the timeline: the panel lists the end it departs
    // from, scrolled to its departure, marked as selected there and on the
    // timeline, and its actions show above both. Selected by the keyboard,
    // the focus goes to the first action, as the trip's button is drawn anew.
    select(tripId, { keyboard = false } = {}) {
      this.selected = tripId
      this.showInPanel(tripId)
      if (keyboard) slot("trip-actions").querySelector("[data-action]").focus()
    },

    // The panel at the end a trip departs from, scrolled to its departure.
    showInPanel(tripId) {
      this.end = runningTrip(currentDay(this.day), tripId).trip.goBack
      this.render()
      this.scrollPanelTo(slot("departures").querySelector(`tr[data-trip="${tripId}"]`))
    },

    // One of the selected trip's actions. Each hands the focus to the
    // panel's own control for it, so the change it makes, its refusals and
    // its words are the panel's: the trip's vehicle menu or departure field,
    // or the form recording its vehicle back at the end it heads to.
    // Deselecting closes the actions; from the keyboard, the focus goes back
    // to the trip.
    act(action, { keyboard }) {
      const tripId = this.selected
      if (action === "deselect") {
        this.selected = null
        this.render()
        if (keyboard) timeline.focusTrip(tripId)
        return
      }
      if (action === "record") {
        const { vehicle, trip } = runningTrip(currentDay(this.day), tripId)
        this.selectEnd(OTHER_END[trip.goBack])
        form.querySelector("[data-record-vehicle]").value = String(vehicle)
        form.querySelector("[data-record-time]").focus()
        return
      }
      if (!slot("departures").querySelector(`tr[data-trip="${tripId}"]`)) this.showInPanel(tripId)
      const control = slot("departures").querySelector(`tr[data-trip="${tripId}"] [data-control=${action}]`)
      control.focus()
      if (action === "departure") control.select()
    },

    // The mark of now selected: the panel back at the end listed first,
    // scrolled to its next departure, the timeline to now, and no trip
    // selected.
    toNow() {
      this.end = defaultEnd(this.day)
      this.selected = null
      this.render()
      this.scrollPanelToNow()
      timeline.scrollToNow()
    },

    // The departures scrolled to the first one at or after now, the line of
    // now right before it.
    scrollPanelToNow() {
      const line = slot("departures").querySelector("tr[data-now-line]")
      this.scrollPanelTo(line.nextElementSibling ?? line)
    },

    // The departures' frame scrolled so a row shows right below the header
    // with up to PANEL_CONTEXT departures before it. Only the frame scrolls,
    // so the page stays where it is.
    scrollPanelTo(row) {
      let anchor = row
      let before = 0
      while (before < PANEL_CONTEXT && anchor.previousElementSibling) {
        anchor = anchor.previousElementSibling
        if (anchor.matches("tr[data-trip]")) before += 1
      }
      const frame = root.querySelector("[data-departures-frame]")
      frame.scrollTop += anchor.getBoundingClientRect().top - frame.querySelector("thead").getBoundingClientRect().bottom
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
        menu.value = tr.dataset.vehicle
        this.reject(tr, menu, refusalText(result.refused), false)
        return
      }
      this.commitFromTable(result, { trip: tr.dataset.trip, control: "vehicle" })
    },

    // What dropping a trip on a vehicle's lane would do, by the same change
    // as giving its departure to that vehicle in the panel: the trips of
    // that vehicle it would exchange, or the refusal.
    previewDrop(tripId, vehicle) {
      const result = changeVehicle(this.day, { tripId, vehicle, at: "" })
      if (result.refused) return { refused: result.refused }
      const tripsOf = (day) => currentDay(day).vehicles.find((candidate) => candidate.number === vehicle).trips.map((trip) => trip.id)
      const kept = new Set(tripsOf(result))
      return { exchanged: tripsOf(this.day).filter((id) => !kept.has(id)) }
    },

    // A trip dropped on another vehicle's lane: its departure given to that
    // vehicle as from the panel's menu, with the reason typed above the
    // departures; refused, the timeline says why under that lane.
    dropOnLane(tripId, vehicle) {
      const result = changeVehicle(this.day, { tripId, vehicle, reason: changeReason.value.trim(), at: now().toISOString() })
      if (result.refused) {
        timeline.refuse(vehicle, refusalText(result.refused))
        return
      }
      this.commitFromTable(result)
    },

    // A trip dropped along its own lane: the minute it was dropped at typed
    // as its departure, as in the panel's field, with the reason typed above
    // the departures.
    dropAlongLane(tripId, departure) {
      this.commitFromTable(changeDeparture(this.day, { tripId, departure, reason: changeReason.value.trim(), at: now().toISOString() }))
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
      // The minute drawn, which the timeline and the departures now show.
      this.minute = minutes
      this.departuresMinute = minutes
      slot("date").textContent = formatDay(labels, this.day.date)
      slot("basis").textContent = basisText(labels, this.day.basis)
      this.writeFigures(current.figures, "data-figure", "shortest-detail")
      timeline.draw(this.day, current, minutes, this.selected)
      for (const button of root.querySelectorAll("[data-end]")) button.setAttribute("aria-pressed", String(Number(button.dataset.end) === this.end))
      slot("arrival-column").textContent = fill(labels.arrivalColumn, { stop: endName(this.end) })
      slot("departures").replaceChildren(...this.departureRows(current, minutes))
      this.renderStanding(current, minutes)
      this.renderRecordForm(current)
      this.renderActions(current)
      this.renderChanges()
    },

    // Now at another minute without the dispatcher doing anything, as the
    // minute clock or the page shown again tells, as in the requirement "Day
    // dispatch view follows the clock": the timeline's mark and line of now,
    // the vehicles at the end and the departures drawn for it. Within the
    // minute drawn last nothing changes, so a clock held still, as the system
    // specs hold it, draws nothing.
    refreshNow() {
      if (!this.day) return
      const minutes = minutesOfDay(this.day.date, now())
      if (minutes === this.minute) return
      this.minute = minutes
      const current = currentDay(this.day)
      timeline.moveNow(minutes)
      this.renderStanding(current, minutes)
      this.refreshDepartures()
    },

    // The departures drawn for the minute shown, unless the focus is in their
    // frame or a refused change is explained under one of them: then they
    // stay as drawn, so a menu being chosen from or a time being typed is
    // left alone. focusLeft says the focus is leaving their frame. Their
    // statuses and their line of now move only when now passes a departure,
    // so otherwise only the line's time changes and the rows, their controls
    // and the frame's scroll stay.
    refreshDepartures({ focusLeft = false } = {}) {
      const held = this.rejection || (!focusLeft && departuresFrame.contains(document.activeElement))
      if (this.minute === this.departuresMinute || held) return
      const current = currentDay(this.day)
      const statuses = (minutes) => departuresAt(current, this.end, minutes).map((row) => row.status).join()
      if (statuses(this.minute) === statuses(this.departuresMinute)) {
        slot("departures").querySelector("tr[data-now-line] [data-slot=now]").textContent = fill(labels.nowLine, { time: time(this.minute) })
      } else {
        const scrolled = departuresFrame.scrollTop
        slot("departures").replaceChildren(...this.departureRows(current, this.minute))
        departuresFrame.scrollTop = scrolled
      }
      this.departuresMinute = this.minute
    },

    // The day's figures into the elements carrying the attribute, the
    // header's or the printed record's, and the vehicle and the departure of
    // the shortest stop into the slot named detail.
    writeFigures({ swaps, typed, waiting, shortestStop }, attribute, detail) {
      const figure = (name, value) => { root.querySelector(`[${attribute}=${name}]`).textContent = value }
      figure("swaps", swaps)
      figure("typed", typed)
      figure("waiting", waiting)
      figure("shortest", shortestStop?.minutes ?? labels.none)
      slot(detail).textContent = shortestStop ? fill(labels.shortestDetail, { vehicle: vehicleName(shortestStop.vehicle), departure: time(shortestStop.departure) }) : ""
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
    // the status; marked when it is the trip selected on the timeline.
    departureRow(row, vehicles) {
      const tr = template("departure-row").content.firstElementChild.cloneNode(true)
      const departure = time(row.departure)
      tr.dataset.trip = row.id
      tr.dataset.departure = row.departure
      tr.dataset.vehicle = row.vehicle
      tr.dataset.status = row.status
      tr.toggleAttribute("data-swapped", row.vehicle !== row.plannedVehicle)
      tr.toggleAttribute("data-selected", row.id === this.selected)
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

    // The selected trip's actions above the timeline and the panel: which
    // trip it is, with the panel's words for its actions; nothing when no
    // trip is selected.
    renderActions(current) {
      const place = slot("trip-actions")
      if (this.selected === null) {
        place.replaceChildren()
        return
      }
      const { vehicle, trip } = runningTrip(current, this.selected)
      const to = OTHER_END[trip.goBack]
      const bar = template("timeline-actions").content.firstElementChild.cloneNode(true)
      bar.querySelector("[data-slot=trip]").textContent = fill(timelineWords.selectedTrip, { vehicle: vehicleName(vehicle), time: time(trip.departure) })
      bar.querySelector("[data-slot=detail]").textContent = fill(timelineWords.selectedDetail, {
        stop: endName(trip.goBack),
        direction: timelineWords.directions[trip.goBack],
        swapped: trip.plannedVehicle === vehicle ? "" : fill(timelineWords.swapped, { vehicle: vehicleName(trip.plannedVehicle) }),
        arrival: time(trip.arrival),
        to: endName(to),
      })
      bar.querySelector("[data-action=record]").textContent = fill(labels.recordAction, { vehicle: vehicleName(vehicle), stop: endName(to) })
      place.replaceChildren(bar)
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

    // The day record as it prints, drawn from the day as it stands when the
    // browser is about to print: the summary page, with the day, what it was
    // planned from, the figures, every vehicle's rest and the change log,
    // and one sheet per vehicle in vehicle number order.
    drawRecord() {
      const current = currentDay(this.day)
      slot("record-date").textContent = formatDay(labels, this.day.date)
      slot("record-basis").textContent = basisText(labels, this.day.basis)
      this.writeFigures(current.figures, "data-record-figure", "record-shortest-detail")
      const credits = [...current.credits].sort((a, b) => a.vehicle - b.vehicle)
      slot("record-credits").replaceChildren(...credits.map(({ vehicle, now, planned }) => this.item("record-credit", {
        vehicle: vehicleName(vehicle),
        now: minutesText(now, labels.creditShorter, labels.creditMinutes),
        planned: minutesText(planned, labels.creditPlannedShorter, labels.creditPlanned),
      })))
      this.drawRecordChanges()
      const paper = { printHeader: sheetHeader(this.day, labels), origins: { 0: endName(0), 1: endName(1) } }
      const vehicles = [...current.vehicles].sort((a, b) => a.number - b.number)
      root.querySelector("[data-record-sheets]").replaceChildren(...vehicles.map((vehicle) => this.recordSheet(vehicle, paper)))
    },

    // One vehicle's printed sheet: the timetable's sheet with the marks after
    // its times, and the notes explaining them under its table, when it has
    // any.
    recordSheet(vehicle, paper) {
      const fragment = sheets.sheet(vehicle, { ...paper, ...marksFor(vehicle, labels) })
      const notes = sheetNotes(this.day, vehicle, labels)
      if (notes.length > 0) {
        const list = template("sheet-notes").content.firstElementChild.cloneNode(true)
        list.replaceChildren(...notes.map((note) => Object.assign(document.createElement("li"), { textContent: note })))
        fragment.querySelector("[data-rest-credit]").before(list)
      }
      return fragment
    },

    // The printed change log: every change in the order recorded, when, what
    // it did, its reason and whether it is undone; without changes, the line
    // that says so in place of the table.
    drawRecordChanges() {
      const { changes } = this.day
      slot("record-changes-heading").textContent = fill(labels.changesHeading, { count: changes.length })
      slot("record-changes").replaceChildren(...changes.map((change) => {
        const row = this.item("record-change", { at: time(minutesOfDay(this.day.date, new Date(change.at))), text: this.changeText(change), reason: change.reason })
        row.querySelector("[data-slot=undone]").hidden = !change.undone
        return row
      }))
      slot("record-changes").closest("table").hidden = changes.length === 0
      root.querySelector("[data-record-changes-none]").hidden = changes.length > 0
    },

    // One of the day record's files downloaded, the change log or the day's
    // sheets, in the words of the page and with its ends' names.
    exportFile(kind) {
      const words = { ...labels.csv, stops: { 0: endName(0), 1: endName(1) } }
      const text = kind === "changes" ? changeLogCsv(this.day, words) : sheetsCsv(this.day, currentDay(this.day), words)
      download(csvFileName(this.day, kind), text)
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
  // Departures left as drawn while the focus was in their frame are drawn
  // for now once it leaves; a departure typed there was handled first.
  departuresFrame.addEventListener("focusout", (event) => {
    if (!departuresFrame.contains(event.relatedTarget)) view.refreshDepartures({ focusLeft: true })
  })
  form.addEventListener("submit", (event) => view.record(event))
  slot("trip-actions").addEventListener("click", (event) => {
    const action = event.target.closest("[data-action]")?.dataset.action
    if (action) view.act(action, { keyboard: event.detail === 0 })
  })
  root.querySelector("[data-undo]").addEventListener("click", () => view.commit(undoLast(view.day)))
  for (const button of root.querySelectorAll("[data-export]")) button.addEventListener("click", () => view.exportFile(button.dataset.export))
  // The browser's print; the record is drawn when the browser announces it,
  // whether it starts here or from the browser's own menu.
  root.querySelector("[data-print-record]").addEventListener("click", () => window.print())
  return view
}

// A file made in the browser downloaded through a link to its blob, so
// nothing is sent to the server.
function download(name, text) {
  const address = URL.createObjectURL(new Blob([text], { type: "text/csv;charset=utf-8" }))
  const link = document.createElement("a")
  link.href = address
  link.download = name
  document.body.append(link)
  link.click()
  link.remove()
  setTimeout(() => URL.revokeObjectURL(address), DOWNLOAD_KEPT_MS)
}

// The trip and the control a focused element is, when it is one of a
// departure's controls, so the focus can go back to it once the view is
// drawn anew.
function focusOf(element) {
  const tr = element?.closest?.("tr[data-trip]")
  return tr && element.dataset.control ? { trip: tr.dataset.trip, control: element.dataset.control } : null
}

// The trip with the identifier and the number of the vehicle running it as
// the day stands.
function runningTrip(current, tripId) {
  for (const vehicle of current.vehicles) {
    const trip = vehicle.trips.find((candidate) => candidate.id === tripId)
    if (trip) return { vehicle: vehicle.number, trip }
  }
  throw new Error(`no trip ${tripId} in the day`)
}

// What the day was planned from: the covered day or days with their day
// type, the percentile and the rest minutes.
function basisText(labels, { days, dayType, percentile, buffer }) {
  const values = { dayType: labels.dayTypes[dayType], percentile, buffer }
  if (days.length === 1) return fill(labels.basisOne, { ...values, day: formatDay(labels, days[0]) })
  return fill(labels.basisRange, { ...values, first: formatDay(labels, days[0]), last: formatDay(labels, days.at(-1)), count: days.length })
}
