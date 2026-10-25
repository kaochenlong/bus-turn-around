// The timetable page in the browser: reads the data the server embedded, lays
// the timetable out, draws one sheet per vehicle from the server's templates,
// and lays it out again whenever a control changes. Nothing is sent back or
// stored; the rest and the percentile are written into the address, so a
// reload starts from them. The page is complete without the sheets only in
// the sense that it says it needs JavaScript.
import { addRow, addVehicle, changeDeparture, countEdited, deleteRow } from "./edits.js"
import { clock, fieldClock, parseClock, stopText } from "./format.js"
import { layOut, plan } from "./layout.js"
import { minimumCredit } from "./rest_windows.js"
import { rows } from "./rows.js"

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

    init() {
      const script = this.$root.querySelector("script[data-timetable-data]")
      if (!script) return
      this.data = JSON.parse(script.textContent)
      this.sheetTemplate = this.$root.querySelector("template[data-sheet-template]")
      this.rowTemplate = this.$root.querySelector("template[data-row-template]")
      this.sheets = this.$root.querySelector("[data-sheets]")
      this.controls = this.$root.querySelector("[data-timetable-controls]")
      this.readControls()
      this.$root.querySelector("[data-needs-script]")?.setAttribute("hidden", "")
      const print = this.$root.querySelector("button[data-print]")
      if (print) {
        print.hidden = false
        print.addEventListener("click", () => window.print())
      }
      this.controls.addEventListener("change", () => this.regenerate())
      this.sheets.addEventListener("change", (event) => this.departureChanged(event))
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

    // A vehicle added beside the laid-out ones, from the direction and the
    // first departure typed into the control below the sheets; an invalid
    // time marks the control and adds nothing.
    newVehicle() {
      const control = this.addVehicleControl
      const input = control.querySelector("[data-add-vehicle-input]")
      const minutes = parseClock(input.value)
      if (minutes === null) {
        control.setAttribute("data-invalid", "")
        return
      }
      control.removeAttribute("data-invalid")
      const goBack = Number(control.querySelector("[data-add-vehicle-direction]").value)
      this.vehicles = addVehicle(this.vehicles, { goBack, departure: minutes }, this.planner(), this.holds())
      input.value = ""
      this.render()
    },

    // A departure typed anew: an invalid time marks the cell and puts the
    // previous time back; a valid one plans that trip again and recomputes
    // everything that follows from it, leaving the other departures alone.
    departureChanged(event) {
      const input = event.target.closest("[data-departure-input]")
      if (!input) return
      const cell = input.closest("[data-departure]")
      const minutes = parseClock(input.value)
      if (minutes === null) {
        cell.setAttribute("data-invalid", "")
        input.value = fieldClock(Number(cell.dataset.departure))
        return
      }
      this.vehicles = changeDeparture(this.vehicles, { vehicle: Number(cell.dataset.sheet), index: Number(cell.dataset.index), departure: minutes }, this.planner())
      this.render()
    },

    sheetClicked(event) {
      const remove = event.target.closest("[data-delete-row]")
      if (remove) {
        this.vehicles = deleteRow(this.vehicles, { vehicle: Number(remove.dataset.sheet), row: Number(remove.dataset.row) })
        this.render()
        return
      }
      if (event.target.closest("[data-add]")) this.addRow(event.target.closest("[data-vehicle]"))
    },

    // Enter in the add control's field adds the row, as the button does.
    sheetKeyPressed(event) {
      if (event.key !== "Enter" || !event.target.closest("[data-add-input]")) return
      event.preventDefault()
      this.addRow(event.target.closest("[data-vehicle]"))
    },

    // A row added to a sheet from the time typed into its add control; an
    // invalid time marks the control and adds nothing.
    addRow(section) {
      const control = section.querySelector("[data-add-row]")
      const minutes = parseClock(control.querySelector("[data-add-input]").value)
      if (minutes === null) {
        control.setAttribute("data-invalid", "")
        return
      }
      this.vehicles = addRow(this.vehicles, { vehicle: Number(section.dataset.vehicle), departure: minutes }, this.planner(), this.holds())
      this.render()
    },

    // The controls as they stand: the server's values on the first load, the
    // dispatcher's when Turbo brings the page back from its cache.
    readControls() {
      this.percentile = Number(this.controls.querySelector("select[name=p]").value)
      this.buffer = this.inRange(this.controls.querySelector("input[name=buffer]"), this.data.bufferRange, this.buffer ?? this.data.buffer)
      this.departures = Object.fromEntries(DIRECTIONS.map((goBack) => [goBack, HOURS.map((hour) => {
        const input = this.controls.querySelector(`input[name="departures[${goBack}][${hour}]"]`)
        return this.inRange(input, this.data.departuresRange, this.departures?.[goBack]?.[hour] ?? this.data.departures[goBack][hour])
      })]))
    },

    // A number input's whole value within the range; otherwise the fallback,
    // written back into the input so the page and the layout agree.
    inRange(input, [min, max], fallback) {
      const value = Number(input.value)
      const ok = input.value.trim() !== "" && Number.isInteger(value) && value >= min && value <= max
      if (!ok) input.value = fallback
      return ok ? value : fallback
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
      return Object.fromEntries(DIRECTIONS.map((goBack) => [goBack, this.data.stoppingEnds.includes(goBack) ? this.buffer : this.data.holds[goBack]]))
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

    render() {
      this.sheets.replaceChildren(...this.vehicles.map((vehicle) => this.sheet(vehicle)))
      this.figure("vehicles", this.vehicles.length)
      for (const goBack of DIRECTIONS) {
        this.figure(`departures-${goBack}`, this.vehicles.reduce((count, vehicle) => count + vehicle.trips.filter((trip) => trip.goBack === goBack).length, 0))
      }
      this.figure("edited", countEdited(this.vehicles))
      this.figure("percentile", this.percentile)
      this.figure("buffer", this.buffer)
      for (const row of this.$root.querySelectorAll("[data-section=overruns] tr[data-percentile]")) {
        const selected = Number(row.dataset.percentile) === this.percentile
        row.toggleAttribute("data-selected", selected)
        SELECTED_ROW_CLASSES.forEach((name) => row.classList.toggle(name, selected))
      }
    },

    figure(name, value) {
      for (const node of this.$root.querySelectorAll(`[data-timetable-header] [data-value="${name}"]`)) node.textContent = value
    },

    // A direction's name from the sheet template. Read as an attribute: the
    // dataset turns data-direction-0 into "direction-0", not direction0.
    directionName(goBack) {
      return this.sheetTemplate.getAttribute(`data-direction-${goBack}`)
    },

    // One vehicle's sheet from the template: the title, the rows, the add
    // control's wording, the all-day legend when a trip fell back, and the
    // rest in the tightest four hours.
    sheet(vehicle) {
      const labels = this.sheetTemplate.dataset
      const fragment = this.sheetTemplate.content.cloneNode(true)
      const section = fragment.querySelector("[data-vehicle]")
      section.dataset.vehicle = vehicle.number
      section.id = `vehicle-${vehicle.number}`
      const title = labels.title.replace("%{number}", vehicle.number)
      section.querySelector("[data-slot=title]").textContent = title
      section.querySelector("[data-slot=run-number]").textContent = title
      section.querySelector("[data-slot=print-header]").textContent = labels.printHeader.replace("%{percentile}", this.percentile).replace("%{buffer}", this.buffer)
      const body = section.querySelector("[data-slot=rows]")
      const sheetRows = rows(vehicle.trips)
      for (const row of sheetRows) body.append(this.row(vehicle, row, labels))
      this.fillRows(body, sheetRows.length)
      section.querySelector("[data-slot=add-label]").textContent = labels.addLabel.replace("%{direction}", this.directionName(vehicle.trips[0].goBack))
      section.querySelector("[data-fallback-legend]").hidden = !vehicle.trips.some((trip) => trip.fallback)
      const credit = minimumCredit(vehicle.trips)
      const line = section.querySelector("[data-rest-credit]")
      line.dataset.restCredit = credit ?? ""
      line.textContent = credit === null ? labels.shorterText : labels.restCreditText.replace("%{minutes}", credit)
      return fragment
    },

    // Blank rows after the trips until the sheet has the paper's row count,
    // shown only when printed; the last cell is the actions column, which is
    // not printed either.
    fillRows(body, count) {
      const columns = this.sheetTemplate.content.querySelectorAll("thead th").length
      for (let i = count; i < Number(this.sheetTemplate.dataset.minRows); i += 1) {
        const tr = document.createElement("tr")
        tr.setAttribute("data-filler", "")
        tr.className = "hidden print:table-row"
        for (let c = 0; c < columns; c += 1) {
          const td = document.createElement("td")
          if (c === columns - 1) td.className = "print:hidden"
          tr.append(td)
        }
        body.append(tr)
      }
    },

    row(vehicle, row, labels) {
      const fragment = this.rowTemplate.content.cloneNode(true)
      const tr = fragment.querySelector("[data-row]")
      tr.dataset.row = row.number
      const departures = tr.querySelectorAll("[data-departure]")
      const arrivals = tr.querySelectorAll("[data-arrival]")
      const stops = tr.querySelectorAll("[data-stop]")
      this.departureCell(departures[0], row.first, vehicle, (row.number - 1) * 2, labels)
      tr.querySelector("[data-slot=origin]").textContent = this.data.stopNames[row.first.goBack] ?? this.directionName(row.first.goBack)
      this.arrivalCell(arrivals[0], row.first, labels)
      stops[0].textContent = stopText(row.stop)
      if (row.second) {
        this.departureCell(departures[1], row.second, vehicle, (row.number - 1) * 2 + 1, labels)
        this.arrivalCell(arrivals[1], row.second, labels)
      } else {
        departures[1].replaceChildren()
      }
      stops[1].textContent = stopText(row.nextStop)
      const remove = tr.querySelector("[data-delete-row]")
      remove.dataset.sheet = vehicle.number
      remove.dataset.row = row.number
      return fragment
    },

    // A departure cell: the printed time, the editable field with the
    // service-day time, which sheet and trip it belongs to (data-sheet, so
    // that data-vehicle marks sheets only), and the edited mark.
    departureCell(cell, trip, vehicle, index, labels) {
      cell.dataset.departure = trip.departure
      cell.dataset.sheet = vehicle.number
      cell.dataset.index = index
      cell.toggleAttribute("data-edited", trip.edited)
      cell.querySelector("span").textContent = clock(trip.departure, labels.nextDay)
      const input = cell.querySelector("input")
      input.value = fieldClock(trip.departure)
      input.title = trip.edited ? labels.editedTitle : ""
      EDITED_CLASSES.forEach((name) => input.classList.toggle(name, trip.edited))
    },

    arrivalCell(cell, trip, labels) {
      cell.dataset.arrival = trip.arrival
      cell.toggleAttribute("data-fallback", trip.fallback)
      cell.textContent = clock(trip.arrival, labels.nextDay) + (trip.fallback ? labels.fallbackMark : "")
    },
  }
}
