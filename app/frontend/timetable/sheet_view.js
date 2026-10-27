// A vehicle's sheet drawn from the two templates TimetableSheetComponent
// writes, as the timetable page and the day record both print it: one row
// per round trip, blank rows after them up to the paper's count, every
// row's printed times with the marks the caller gives, its first stop and
// its stops, the run number, the line under the form's title and the rest
// in the tightest four hours. What a page adds on screen, such as the
// timetable page's time fields and controls, is that page's own.
import { clock, stopText } from "./format.js"
import { minimumCredit } from "./rest_windows.js"
import { rows } from "./rows.js"

// The sheets of the sheet and row templates. paper, given for every sheet,
// says what the page prints: printHeader, the line under the form's title;
// origins, the name of the end each direction leaves from; and
// departureMark(trip) and arrivalMark(trip), the text right after a time.
export function sheetView(sheetTemplate, rowTemplate) {
  const labels = sheetTemplate.dataset

  // A blank row of the paper, shown only when printed, with a cell for every
  // column; the first is the actions column, which is not printed either.
  const fillerRow = () => {
    const tr = document.createElement("tr")
    tr.setAttribute("data-filler", "")
    tr.className = "hidden print:table-row"
    const columns = sheetTemplate.content.querySelectorAll("thead th").length
    for (let c = 0; c < columns; c += 1) {
      const td = document.createElement("td")
      if (c === 0) td.className = "print:hidden"
      tr.append(td)
    }
    return tr
  }

  const departureCell = (cell, trip, paper) => {
    cell.dataset.departure = trip.departure
    cell.querySelector("span").textContent = clock(trip.departure, labels.nextDay) + paper.departureMark(trip)
  }

  const arrivalCell = (cell, trip, paper) => {
    cell.dataset.arrival = trip.arrival
    cell.textContent = clock(trip.arrival, labels.nextDay) + paper.arrivalMark(trip)
  }

  // A row's values: the two trips' times and the stops after them, and the
  // first stop's name; a row of one trip has no second departure.
  const writeRow = (tr, row, paper) => {
    tr.dataset.row = row.number
    const departures = tr.querySelectorAll("[data-departure]")
    const arrivals = tr.querySelectorAll("[data-arrival]")
    const stops = tr.querySelectorAll("[data-stop]")
    departureCell(departures[0], row.first, paper)
    tr.querySelector("[data-slot=origin]").textContent = paper.origins[row.first.goBack]
    arrivalCell(arrivals[0], row.first, paper)
    stops[0].textContent = stopText(row.stop)
    if (row.second) {
      departureCell(departures[1], row.second, paper)
      arrivalCell(arrivals[1], row.second, paper)
    } else {
      departures[1].replaceChildren()
    }
    stops[1].textContent = stopText(row.nextStop)
  }

  const view = {
    // A new sheet for the vehicle: a row from the row template for each of
    // its round trips, the blank rows the paper has, then its values.
    sheet(vehicle, paper) {
      const fragment = sheetTemplate.content.cloneNode(true)
      const body = fragment.querySelector("[data-slot=rows]")
      const count = rows(vehicle.trips).length
      for (let i = 0; i < count; i += 1) body.append(rowTemplate.content.cloneNode(true))
      for (let i = count; i < Number(labels.minRows); i += 1) body.append(fillerRow())
      view.write(fragment.querySelector("[data-vehicle]"), vehicle, paper)
      return fragment
    },

    // The printed values into a sheet just made or one already on the page
    // with a row element for each of the vehicle's round trips.
    write(section, vehicle, paper) {
      section.dataset.vehicle = vehicle.number
      const title = labels.title.replace("%{number}", vehicle.number)
      section.querySelector("[data-slot=title]").textContent = title
      section.querySelector("[data-slot=run-number]").textContent = title
      section.querySelector("[data-slot=print-header]").textContent = paper.printHeader
      const sheetRows = rows(vehicle.trips)
      section.querySelectorAll("tr[data-row]").forEach((tr, i) => writeRow(tr, sheetRows[i], paper))
      const credit = minimumCredit(vehicle.trips)
      const line = section.querySelector("[data-rest-credit]")
      line.dataset.restCredit = credit ?? ""
      line.textContent = credit === null ? labels.shorterText : labels.restCreditText.replace("%{minutes}", credit)
    },
  }
  return view
}
