// The timetable page in the browser: reads the data the server embedded, lays
// the timetable out, draws one sheet per vehicle from the server's templates,
// and lays it out again whenever a control changes. Nothing is sent back or
// stored; the rest and the percentile are written into the address, so a
// reload starts from them. The page is complete without the sheets only in
// the sense that it says it needs JavaScript.
import { addRow, addVehicle, changeDeparture, countEdited, countPushed, deleteRow, pushedMinutes } from "./edits.js"
import { wholeInRange } from "./fields.js"
import { clock, fieldClock, parseClock } from "./format.js"
import { holdsFor, layOut, plan } from "./layout.js"
import { rows } from "./rows.js"
import { sheetView } from "./sheet_view.js"

const DIRECTIONS = [0, 1]
const HOURS = Array.from({ length: 24 }, (_, hour) => hour)
const EDITED_CLASSES = ["underline", "decoration-teal-700", "decoration-2", "underline-offset-3"]
const SELECTED_ROW_CLASSES = ["font-semibold", "text-slate-900"]

export function timetable() {
  return {
    data: null,
    percentile: null,
    buffer: null,
    departures: null,
    vehicles: [],
    // The one field on the page whose typed time was rejected, if any: the
    // field, the cell or control marked invalid, and the message about it.
    rejection: null,
    // The departure field typed into since it was last submitted, if any:
    // only the focused field takes typing, so there is at most one.
    typedField: null,

    init() {
      const script = this.$root.querySelector("script[data-timetable-data]")
      if (!script) return
      this.data = JSON.parse(script.textContent)
      this.sheetTemplate = this.$root.querySelector("template[data-sheet-template]")
      this.sheetView = sheetView(this.sheetTemplate, this.$root.querySelector("template[data-row-template]"))
      this.sheets = this.$root.querySelector("[data-sheets]")
      this.controls = this.$root.querySelector("[data-timetable-controls]")
      this.readControls()
      this.$root.querySelector("[data-needs-script]")?.setAttribute("hidden", "")
      const print = this.$root.querySelector("button[data-print]")
      if (print) {
        print.hidden = false
        print.addEventListener("click", () => window.print())
      }
      // Turbo caches the page for the back button as the dispatcher left it,
      // but without the rejection: it answers what was just typed, and the
      // component that comes back with the page knows nothing of it.
      this.restoreBeforeCache = () => this.clearRejection()
      document.addEventListener("turbo:before-cache", this.restoreBeforeCache)
      this.controls.addEventListener("change", () => this.regenerate())
      this.sheets.addEventListener("input", (event) => this.departureTyped(event))
      this.sheets.addEventListener("focusout", (event) => this.departureLeft(event))
      this.sheets.addEventListener("click", (event) => this.sheetClicked(event))
      this.sheets.addEventListener("keydown", (event) => this.sheetKeyPressed(event))
      this.addVehicleControl = this.$root.querySelector("[data-add-vehicle]")
      if (this.addVehicleControl) {
        this.addVehicleControl.hidden = false
        this.addVehicleControl.querySelector("[data-add-vehicle-button]").addEventListener("click", () => this.newVehicle())
        this.addVehicleControl.querySelector("[data-add-vehicle-input]").addEventListener("keydown", (event) => {
          if (event.key !== "Enter") return
          event.preventDefault()
          this.newVehicle()
        })
      }
      this.layOut()
    },

    destroy() {
      document.removeEventListener("turbo:before-cache", this.restoreBeforeCache)
    },

    // A vehicle added beside the laid-out ones, from the direction and the
    // first departure typed into the control below the sheets, with the
    // focus back in its emptied field; an invalid time is rejected and adds
    // nothing.
    newVehicle() {
      const control = this.addVehicleControl
      const input = control.querySelector("[data-add-vehicle-input]")
      const minutes = parseClock(input.value)
      if (minutes === null) {
        this.reject(input, control, control.querySelector("[data-add-vehicle-rejection]"), input.value)
        return
      }
      const goBack = Number(control.querySelector("[data-add-vehicle-direction]").value)
      this.vehicles = addVehicle(this.vehicles, { goBack, departure: minutes }, this.planner(), this.holds())
      input.value = ""
      this.render()
      input.focus()
    },

    departureTyped(event) {
      const input = event.target.closest("[data-departure-input]")
      if (input) this.typedField = input
    },

    departureLeft(event) {
      const input = event.target.closest("[data-departure-input]")
      if (input) this.submitDeparture(input)
    },

    // A departure typed anew, when its field is left or on Enter: an invalid
    // time is rejected and the previous time put back; the trip's own time
    // again only rewrites the field; any other time plans that trip again,
    // pushes the trips after it on the same sheet that no longer connect, and
    // writes that sheet anew in place, leaving the other sheets alone.
    // Nothing is drawn again, so the focus stays where the dispatcher put it.
    // A field not typed into since it was last submitted has nothing to
    // submit, whatever it reads: Chrome fires change for a field the page
    // wrote back, and none for the same text typed again.
    submitDeparture(input) {
      if (input !== this.typedField) return
      this.typedField = null
      const cell = input.closest("[data-departure]")
      const current = Number(cell.dataset.departure)
      const typed = input.value
      const minutes = parseClock(typed)
      if (minutes === null) {
        input.value = fieldClock(current)
        this.reject(input, cell, cell.closest("[data-vehicle]").querySelector("[data-rejection]"), typed)
        return
      }
      this.clearRejection()
      if (minutes === current) {
        input.value = fieldClock(minutes)
        return
      }
      const number = Number(cell.dataset.sheet)
      this.vehicles = changeDeparture(this.vehicles, { vehicle: number, index: Number(cell.dataset.index), departure: minutes }, this.planner(), this.holds())
      this.writeSheet(cell.closest("[data-vehicle]"), this.vehicles.find((vehicle) => vehicle.number === number))
      this.writeFigures()
    },

    sheetClicked(event) {
      const remove = event.target.closest("[data-delete-row]")
      if (remove) {
        this.vehicles = deleteRow(this.vehicles, { vehicle: Number(remove.dataset.sheet), row: Number(remove.dataset.row) }, this.planner(), this.holds())
        this.render()
        return
      }
      if (event.target.closest("[data-add]")) this.addRow(event.target.closest("[data-vehicle]"))
    },

    // Enter submits a departure as leaving its field does, and in the add
    // control's field adds the row, as the button does.
    sheetKeyPressed(event) {
      if (event.key !== "Enter") return
      const departure = event.target.closest("[data-departure-input]")
      if (departure) {
        event.preventDefault()
        this.submitDeparture(departure)
      } else if (event.target.closest("[data-add-input]")) {
        event.preventDefault()
        this.addRow(event.target.closest("[data-vehicle]"))
      }
    },

    // A row added to a sheet from the time typed into its add control; an
    // invalid time is rejected and adds nothing. The sheets are drawn
    // anew, so the focus goes to the new sheet's add field, empty, found by
    // the vehicle's number.
    addRow(section) {
      const control = section.querySelector("[data-add-row]")
      const input = control.querySelector("[data-add-input]")
      const minutes = parseClock(input.value)
      if (minutes === null) {
        this.reject(input, control, section.querySelector("[data-rejection]"), input.value)
        return
      }
      const number = Number(section.dataset.vehicle)
      this.vehicles = addRow(this.vehicles, { vehicle: number, departure: minutes }, this.planner(), this.holds())
      this.render()
      this.sheets.querySelector(`[data-vehicle="${number}"] [data-add-input]`).focus()
    },

    // A typed time that cannot be read: the cell or control is marked
    // invalid, the field is marked as an error and pointed at the message,
    // which quotes what was typed, when anything was, and says how to write a
    // time. The typed text goes in as text and is never read as a pattern.
    // Only the latest rejection on the page is marked.
    reject(field, invalid, message, typed) {
      this.clearRejection()
      const labels = this.sheetTemplate.dataset
      const quoted = typed.trim()
      invalid.setAttribute("data-invalid", "")
      field.setAttribute("aria-invalid", "true")
      field.setAttribute("aria-describedby", message.id)
      message.textContent = quoted === "" ? labels.acceptedWritings : labels.rejectedTyped.replace("%{typed}", () => quoted)
      message.hidden = false
      this.rejection = { field, invalid, message }
    },

    // The rejection's marks taken off, once a time is accepted or the sheets
    // are drawn anew.
    clearRejection() {
      if (!this.rejection) return
      const { field, invalid, message } = this.rejection
      invalid.removeAttribute("data-invalid")
      field.removeAttribute("aria-invalid")
      field.removeAttribute("aria-describedby")
      message.hidden = true
      message.textContent = ""
      this.rejection = null
    },

    // The controls as they stand: the server's values on the first load, the
    // dispatcher's when Turbo brings the page back from its cache.
    readControls() {
      this.percentile = Number(this.controls.querySelector("select[name=p]").value)
      this.buffer = wholeInRange(this.controls.querySelector("input[name=buffer]"), this.data.bufferRange, this.buffer ?? this.data.buffer)
      this.departures = Object.fromEntries(DIRECTIONS.map((goBack) => [goBack, HOURS.map((hour) => {
        const input = this.controls.querySelector(`input[name="departures[${goBack}][${hour}]"]`)
        return wholeInRange(input, this.data.departuresRange, this.departures?.[goBack]?.[hour] ?? this.data.departures[goBack][hour])
      })]))
    },

    // A control changed: lay the whole timetable out again from the controls,
    // discarding the manual edits.
    regenerate() {
      this.readControls()
      this.writeAddress()
      this.layOut()
    },

    layOut() {
      this.vehicles = layOut({ departures: this.departures, runTimes: this.data.runTimes, percentile: this.percentile, holds: this.holds() })
      this.render()
    },

    // The hold after a trip of each direction now: the rest at a stopping end,
    // the measured median at a pass-through end.
    holds() {
      return holdsFor(this.data, this.buffer)
    },

    planner() {
      return (goBack, departure, edited) => plan(this.data.runTimes, this.percentile, goBack, departure, edited)
    },

    // The rest and the percentile into the address without a history entry;
    // the departures per hour and the edits stay in the page.
    writeAddress() {
      const url = new URL(window.location.href)
      url.searchParams.set("buffer", this.buffer)
      url.searchParams.set("p", this.percentile)
      window.history.replaceState(window.history.state, "", url)
    },

    // Every sheet drawn anew, for the edits that change how many sheets or
    // rows there are and for a new layout; each of them clears a rejection.
    render() {
      this.clearRejection()
      this.sheets.replaceChildren(...this.vehicles.map((vehicle) => this.sheet(vehicle)))
      this.writeFigures()
      for (const row of this.$root.querySelectorAll("[data-section=overruns] tr[data-percentile]")) {
        const selected = Number(row.dataset.percentile) === this.percentile
        row.toggleAttribute("data-selected", selected)
        SELECTED_ROW_CLASSES.forEach((name) => row.classList.toggle(name, selected))
      }
    },

    // The header's figures from the vehicles as they stand.
    writeFigures() {
      this.figure("vehicles", this.vehicles.length)
      for (const goBack of DIRECTIONS) {
        this.figure(`departures-${goBack}`, this.vehicles.reduce((count, vehicle) => count + vehicle.trips.filter((trip) => trip.goBack === goBack).length, 0))
      }
      this.figure("edited", countEdited(this.vehicles))
      this.figure("pushed", countPushed(this.vehicles))
      this.figure("percentile", this.percentile)
      this.figure("buffer", this.buffer)
    },

    figure(name, value) {
      for (const node of this.$root.querySelectorAll(`[data-timetable-header] [data-value="${name}"]`)) node.textContent = value
    },

    // A direction's name from the sheet template. Read as an attribute: the
    // dataset turns data-direction-0 into "direction-0", not direction0.
    directionName(goBack) {
      return this.sheetTemplate.getAttribute(`data-direction-${goBack}`)
    },

    // One vehicle's sheet: the paper the sheet view draws, then the planning
    // controls on it.
    sheet(vehicle) {
      const fragment = this.sheetView.sheet(vehicle, this.paper())
      this.writeControls(fragment.querySelector("[data-vehicle]"), vehicle)
      return fragment
    },

    // A sheet's values, into a sheet already on the page with a row element
    // for each of the vehicle's rows: the paper and the planning controls.
    writeSheet(section, vehicle) {
      this.sheetView.write(section, vehicle, this.paper())
      this.writeControls(section, vehicle)
    },

    // What the timetable prints on its sheets: the line under the form's
    // title with the percentile and the rest in use, the first stops by the
    // page's stop names or else the directions, and the all-day mark after
    // the arrival of a trip whose hour fell back; no mark after a departure.
    paper() {
      const labels = this.sheetTemplate.dataset
      return {
        printHeader: labels.printHeader.replace("%{percentile}", this.percentile).replace("%{buffer}", this.buffer),
        origins: Object.fromEntries(DIRECTIONS.map((goBack) => [goBack, this.data.stopNames[goBack] ?? this.directionName(goBack)])),
        departureMark: () => "",
        arrivalMark: (trip) => (trip.fallback ? labels.fallbackMark : ""),
      }
    },

    // The planning parts of a sheet: its id and the id of its rejection
    // message, the add control's wording, the all-day legend when a trip fell
    // back, and every row's controls.
    writeControls(section, vehicle) {
      const labels = this.sheetTemplate.dataset
      section.id = `vehicle-${vehicle.number}`
      section.querySelector("[data-rejection]").id = `rejection-${vehicle.number}`
      section.querySelector("[data-slot=add-label]").textContent = labels.addLabel.replace("%{direction}", this.directionName(vehicle.trips[0].goBack))
      section.querySelector("[data-fallback-legend]").hidden = !vehicle.trips.some((trip) => trip.fallback)
      const sheetRows = rows(vehicle.trips)
      section.querySelectorAll("tr[data-row]").forEach((tr, i) => this.writeRowControls(tr, vehicle, sheetRows[i], labels))
    },

    // A row's controls: each trip's departure field, the all-day mark on each
    // arrival as an attribute, and which row the delete control takes out.
    writeRowControls(tr, vehicle, row, labels) {
      const departures = tr.querySelectorAll("[data-departure]")
      const arrivals = tr.querySelectorAll("[data-arrival]")
      this.departureCell(departures[0], row.first, vehicle, (row.number - 1) * 2, labels)
      arrivals[0].toggleAttribute("data-fallback", row.first.fallback)
      if (row.second) {
        this.departureCell(departures[1], row.second, vehicle, (row.number - 1) * 2 + 1, labels)
        arrivals[1].toggleAttribute("data-fallback", row.second.fallback)
      }
      const remove = tr.querySelector("[data-delete-row]")
      remove.dataset.sheet = vehicle.number
      remove.dataset.row = row.number
    },

    // A departure cell's field: the editable service-day time, which sheet
    // and trip it belongs to (data-sheet, so that data-vehicle marks sheets
    // only), and the edited and pushed marks, which the field's title puts
    // in words.
    departureCell(cell, trip, vehicle, index, labels) {
      const pushed = pushedMinutes(trip)
      cell.dataset.sheet = vehicle.number
      cell.dataset.index = index
      cell.toggleAttribute("data-edited", trip.edited)
      cell.toggleAttribute("data-pushed", pushed > 0)
      const input = cell.querySelector("input")
      input.value = fieldClock(trip.departure)
      input.title = this.marksTitle(trip, pushed, labels)
      EDITED_CLASSES.forEach((name) => input.classList.toggle(name, trip.edited))
    },

    // What marks a departure says: edited by hand, pushed by how many minutes
    // from when, or both, joined; nothing for a trip as laid out.
    marksTitle(trip, pushed, labels) {
      const marks = []
      if (trip.edited) marks.push(labels.editedTitle)
      if (pushed > 0) marks.push(labels.pushedTitle.replace("%{minutes}", pushed).replace("%{time}", clock(trip.original, labels.nextDay)))
      return marks.join(labels.titleSeparator)
    },
  }
}
